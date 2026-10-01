import sys
from PIL import Image

def convert_to_openfpga_rgb888(image_path, output_path):
    img = Image.open(image_path)
    
    # Scale canvas cleanly to 800x800 pixels
    img = img.resize((800, 800), Image.Resampling.LANCZOS)
    img = img.convert("RGB")
    
    binary_data = bytearray()
    
    for y in range(800):
        for x in range(800):
            r, g, b = img.getpixel((x, y))
            
            # Word 0: Upper 8 bits empty padding, Lower 8 bits Red
            word0 = r & 0xFF
            binary_data.append(word0 & 0xFF)
            binary_data.append((word0 >> 8) & 0xFF)
            
            # Word 1: Upper 8 bits Green, Lower 8 bits Blue
            word1 = (g << 8) | b
            binary_data.append(word1 & 0xFF)
            binary_data.append((word1 >> 8) & 0xFF)
            
    with open(output_path, "wb") as f:
        f.write(binary_data)
    print(f"Successfully compiled 24-bit RGB888 asset: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert_image.py <input_image.png/jpg> <output_image.bin>")
        sys.exit(1)
    convert_to_openfpga_rgb888(sys.argv[1], sys.argv[2])

