import struct
import random

def pack_itch_msg(msg_type, fields):
    """
    Packs basic ITCH message fields into standard NASDAQ big-endian binary formats.
    All lengths are padded to perfectly match the NASDAQ ITCH 5.0 spec layout.
    """
    if msg_type == 'S':
        # System Event Message (12 bytes total)
        return struct.pack('>BHH6sB', ord('S'), 0, 0, b'\x00'*6, ord(fields['code']))
    
    elif msg_type == 'R':
        # Stock Directory Message (39 bytes total)
        symbol_padded = fields['symbol'].ljust(8)[:8].encode('ascii')
        
        # 16 Format Specifiers:
        # B(1) + H(1) + H(1) + 6s(1) + 8s(1) + B(1) + B(1) + 4s(1) + B(1) + 2s(1) + B(1) + B(1) + B(1) + B(1) + B(1) + 6s(1) = 16
        payload = struct.pack('>BHH6s8sBB4sB2sBBBBB6s', 
                              ord('R'), 0, 0, b'\x00'*6, 
                              symbol_padded, ord('M'), ord('N'), b'\x00'*4, 
                              ord('N'), b'\x00'*2, ord('Y'), ord('1'), ord('N'), ord(' '), ord('N'),
                              b'\x00'*6)
        return payload
    
    elif msg_type == 'A':
        # Add Order Message (36 bytes total)
        symbol_padded = fields['symbol'].ljust(8)[:8].encode('ascii')
        payload = struct.pack('>BHH6sQBI8sI', ord('A'), 0, 0, b'\x00'*6,
                              fields['ref_num'], ord(fields['side']), fields['shares'],
                              symbol_padded, fields['price'])
        return payload
        
    elif msg_type == 'E':
        # Order Executed Message (31 bytes total)
        payload = struct.pack('>BHH6sQII4s', ord('E'), 0, 0, b'\x00'*6,
                              fields['ref_num'], fields['shares'], fields['match_num'],
                              b'\x00'*4)
        return payload
    return b''

def write_axi_stream_file(filename, packet_batches):
    """
    Writes a custom simulation text vector file.
    Each row simulates one clock cycle on a 32-bit AXI4-Stream interface:
    Format: [HEX DATA] [VALID] [LAST]
    """
    with open(filename, 'w') as f:
        for batch in packet_batches:
            # Accumulate all raw bytes for network packet batch
            raw_bytes = b''
            for msg_type, fields in batch:
                raw_bytes += pack_itch_msg(msg_type, fields)
            
            # Pad the absolute end of the packet payload to match a clean 32-bit word boundary
            remainder = len(raw_bytes) % 4
            if remainder != 0:
                raw_bytes += b'\x00' * (4 - remainder)
            
            # Slice raw byte payload into 32-bit big-endian words
            words = [struct.unpack('>I', raw_bytes[i:i+4])[0] for i in range(0, len(raw_bytes), 4)]
            
            # Write out words cycle by cycle
            num_words = len(words)
            for idx, word in enumerate(words):
                is_last = 1 if (idx == num_words - 1) else 0
                is_valid = 1
                
                # Test Case Insertion: Deliberately inject random tvalid drops 20% of the time
                if random.random() < 0.20 and not is_last:
                    # Write out a stalled/bubble clock cycle
                    f.write(f"{word:08X} 0 0\n")
                
                # Write standard active stream transfer word row
                f.write(f"{word:08X} {is_valid} {is_last}\n")
            
            # Intercept packet gap: Write 3-6 cycles of dead network silence between frames
            for _ in range(random.randint(3, 6)):
                f.write("00000000 0 0\n")

if __name__ == "__main__":
    # Define a clean simulation batch stream mimicking a high-volume market burst
    simulation_burst = [
        # Packet Batch 1: System setup + Stock mappings
        [
            ('S', {'code': 'O'}), # Market Open
            ('R', {'symbol': 'AAPL'}),
            ('R', {'symbol': 'TSLA'}),
            ('R', {'symbol': 'MSFT'})
        ],
        # Packet Batch 2: AAPL & TSLA target matches
        [
            ('A', {'ref_num': 1001, 'side': 'B', 'shares': 500,  'symbol': 'AAPL', 'price': 1500000}), # 150.0000
            ('A', {'ref_num': 1002, 'side': 'S', 'shares': 200,  'symbol': 'TSLA', 'price': 7000000}), # 700.0000
            ('A', {'ref_num': 1003, 'side': 'B', 'shares': 1000, 'symbol': 'MSFT', 'price': 2400000})  # Filter will skip
        ],
        # Packet Batch 3: Volumetric Updates
        [
            ('A', {'ref_num': 1004, 'side': 'B', 'shares': 300,  'symbol': 'AAPL', 'price': 1510000}),
            ('A', {'ref_num': 1005, 'side': 'B', 'shares': 800,  'symbol': 'TSLA', 'price': 7050000})
        ]
    ]
    
    output_path = "itch_test_vectors.txt"
    write_axi_stream_file(output_path, simulation_burst)
    print(f"[SUCCESS] Vector generation complete! File saved to: {output_path}")