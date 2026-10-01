import struct
import os
from PIL import Image

def convert_to_square_rgb565(image_path, output_bin_path):
    """
    Center-crops, resizes, and converts any image into a raw 720x720 RGB565 binary asset.
    """
    print(f"Opening source image: {image_path}")
    img = Image.open(image_path).convert('RGB')
    
    # 1. Calculate a perfect square center-crop
    width, height = img.size
    min_dimension = min(width, height)
    
    left = (width - min_dimension) / 2
    top = (height - min_dimension) / 2
    right = (width + min_dimension) / 2
    bottom = (height + min_dimension) / 2
    
    # 2. Crop and resize to exactly 720x720
    img_cropped = img.crop((left, top, right, bottom))
    img_resized = img_cropped.resize((720, 720), Image.Resampling.LANCZOS)
    
    # 3. Stream pixel data out into binary format
    with open(output_bin_path, 'wb') as f:
        for y in range(720):
            for x in range(720):
                r, g, b = img_resized.getpixel((x, y))
                
                # Compress 8-bit channels down to 5-6-5 bits
                r_5 = (r >> 3) & 0x1F
                g_6 = (g >> 2) & 0x3F
                b_5 = (b >> 3) & 0x1F
                
                # Pack channels into a single 16-bit word
                rgb565 = (r_5 << 11) | (g_6 << 5) | b_5
                
                # Write to file using Little-Endian format (<H)
                f.write(struct.pack('<H', rgb565))
                
    file_size = os.path.getsize(output_bin_path)
    print(f"Conversion complete!")
    print(f"Output path: {output_bin_path}")
    print(f"Dimensions : 720x720 pixels")
    print(f"File Size  : {file_size} bytes (Expected: 1036800)")

# ==========================================
# Run the Converter
# ==========================================
if __name__ == "__main__":
    # Replace 'my_picture.jpg' with the path to your source image file
    input_source = "my_picture.jpg" 
    output_name  = "image.bin"
    
    if os.path.exists(input_source):
        convert_to_square_rgb565(input_source, output_name)
    else:
        print(f"Error: Could not find '{input_source}'. Place your image in this directory and try again.")

