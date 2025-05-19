import os
from PIL import Image

def replace_with_gevernova(logo_path='gevernova.jpg', directory='.'):
    # Load the GE Vernova logo into memory
    ge_logo = Image.open(logo_path)

    # Loop through all PNG images in the specified directory
    for filename in os.listdir(directory):
        if filename.endswith('.png'):
            image_path = os.path.join(directory, filename)

            # Get size of the current PNG image
            with Image.open(image_path) as img:
                png_width, png_height = img.size

            # Resize the logo to match the PNG image dimensions without distortion
            logo_aspect_ratio = ge_logo.width / ge_logo.height
            target_aspect_ratio = png_width / png_height

            # Determine new logo dimensions based on aspect ratios
            if logo_aspect_ratio > target_aspect_ratio:
                # Logo is wider relative to the target aspect ratio
                new_logo_width = png_width
                new_logo_height = int(png_width / logo_aspect_ratio)
            else:
                # Logo is taller relative to the target aspect ratio
                new_logo_height = png_height
                new_logo_width = int(png_height * logo_aspect_ratio)

            # Resize and center-crop the logo to fit the PNG dimensions
            resized_logo = ge_logo.resize((new_logo_width, new_logo_height), Image.LANCZOS)
            resized_logo = resized_logo.crop(((new_logo_width - png_width) // 2, (new_logo_height - png_height) // 2,
                                              (new_logo_width + png_width) // 2, (new_logo_height + png_height) // 2))

            # Save the resized logo as the PNG image, replacing the original content
            resized_logo.save(image_path)

if __name__ == '__main__':
    replace_with_gevernova()
