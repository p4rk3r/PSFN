import argparse
import torch
import numpy as np
import h5py
from psfn import PSFN

def get_args():
    parser = argparse.ArgumentParser(description="Script for running inference using trained PSFN model.")
    parser.add_argument("--model_path", default="model_500.pth", help="Path to the trained model file.")
    parser.add_argument("--hr_sar_path", default="hr_sar.h5", help="Path to the HR SAR image file.")
    parser.add_argument("--lr_polsar_path", default="lr_polsar.h5", help="Path to the LR PolSAR image file.")
    parser.add_argument("--output_path", default="output.tiff", help="Path to save the output image.")
    parser.add_argument("--batch_size", type=int, default=4, help="Batch size for splitting images.")
    parser.add_argument('--nFeat', default=64, type=int, help='the number of feature maps')
    parser.add_argument('--ncha_sinsar', default=1, type=int, help='the number of SinSAR channels')
    parser.add_argument('--ncha_polsar', default=9, type=int, help='the number of PolSAR channels')
    parser.add_argument('--gpu', default='0,1', type=str, help='gpu id')
    args = parser.parse_args()
    return args

def load_lr_polsar(lr_polsar_path):
    with h5py.File(lr_polsar_path, "r") as f:
        group = f['bands']
        # We need to do a better job to extract the C3 components no matter what name have been given.
        datasets = ['C11', 'C12_imag', 'C12_real', 'C13_imag', 'C13_real', 'C22', 'C23_imag', 'C23_real', 'C33']
        lr_polsar = np.stack([group[dataset][()] for dataset in datasets], axis=-1)
    return lr_polsar

def load_hr_sar(hr_sar_path):
    with h5py.File(hr_sar_path, "r") as f:
        group = f['bands']
        hr_sar = group['intensity_all'][()]
    return hr_sar

def process_lr_polsar(image, device, batch_size):
    # Calculate the size that is divisible by the batch size
    height = (image.shape[0] // batch_size) * batch_size
    width = (image.shape[1] // batch_size) * batch_size

    # Crop the image
    image = image[:height, :width, :]

    # Split the image into patches
    image_patches = np.array_split(image, batch_size, axis=0)

    # Convert to PyTorch tensors, add the batch dimension and move them to the device
    image_patches = [torch.from_numpy(patch).permute(2, 0, 1).unsqueeze(0).float().to(device) for patch in image_patches]

    return image_patches


def process_hr_sar(image, device, batch_size):
    # Calculate the size that is divisible by the batch size
    height = (image.shape[0] // (batch_size * 2)) * batch_size * 2
    width = (image.shape[1] // (batch_size * 2)) * batch_size * 2

    # Crop the image
    image = image[:height, :width]

    # Split the image into patches
    image_patches = np.array_split(image, batch_size, axis=0)

    # Convert to PyTorch tensors, add the batch dimension and move them to the device
    image_patches = [torch.from_numpy(patch).unsqueeze(0).unsqueeze(0).float().to(device) for patch in image_patches]

    return image_patches

def run_inference(model, lr_patches, hr_patches, device):
    model.eval()
    output_patches = []
    with torch.no_grad():
        for lr_patch, hr_patch in zip(lr_patches, hr_patches):
            output_patch_tensor = model(lr_patch, hr_patch)
            output_patch = output_patch_tensor.squeeze(0).cpu().numpy()
            output_patches.append(output_patch)
    return np.concatenate(output_patches, axis=1)

def save_output_as_hdf5(output, output_path):
    with h5py.File(output_path, 'w') as f:
        f.create_dataset('C3', data=output)

def main():
    args = get_args()

    # Set the device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Load the trained model
    model = torch.load(args.model_path, map_location=device)

    # Load the LR PolSAR and HR SAR images
    lr_polsar = load_lr_polsar(args.lr_polsar_path)
    hr_sar = load_hr_sar(args.hr_sar_path)

    # Process the images and move them to the device
    lr_patches = process_lr_polsar(lr_polsar, device, args.batch_size)
    hr_patches = process_hr_sar(hr_sar, device, args.batch_size)

    # Run inference
    output = run_inference(model, lr_patches, hr_patches, device)

    # Save the output as an HDF5 file
    save_output_as_hdf5(output, args.output_path)

if __name__ == "__main__":
    main()
