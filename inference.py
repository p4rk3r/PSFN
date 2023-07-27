import torch
from psfn import PSFN
from torch.utils.data import DataLoader

# Parameters
args = {
    'nFeat': 64,
    'ncha_sinsar': 1,
    'ncha_polsar': 9,
}
model_path = 'path_to_your_pretrained_model.pth'  # replace with your model path
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# Load model
model = PSFN(args)
model.load_state_dict(torch.load(model_path, map_location=device))
model = model.to(device)
model.eval()  # set model to evaluation mode

# Load data
lr_polsar = ...  # replace with your low-resolution polarimetric SAR data
hr_sar = ...  # replace with your high-resolution single-polarization SAR data
dataset = [(lr_polsar[i], hr_sar[i]) for i in range(len(lr_polsar))]  # pair the low-res PolSAR and high-res SinSAR images
data_loader = DataLoader(dataset=dataset, batch_size=1, shuffle=False)

# Perform inference
for i, (lr, hr_sar) in enumerate(data_loader):
    lr, hr_sar = lr.to(device), hr_sar.to(device)
    with torch.no_grad():  # disable gradient calculation
        output = model(lr, hr_sar)  # forward propagation
    # now you can do something with the output, e.g., save it or display it

    # Convert the tensor to a numpy array and remove batch dimension
    output_array = output.cpu().numpy().squeeze()

    # Open the existing GeoTIFF file and get the metadata
    with rasterio.open(src_filename) as src:
        metadata = src.meta

    # Update the metadata to reflect the number of bands in the output
    metadata.update(count=output_array.shape[0])

    # Save the output as a GeoTIFF file
    with rasterio.open(f'output_{i}.tif', 'w', **metadata) as dst:
        dst.write(output_array)

