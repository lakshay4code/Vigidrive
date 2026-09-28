import torch
import torchvision.transforms as transforms

from src.model import DrowsinessCNN
from src.config import *

# -------------------------------------
# Device
# -------------------------------------

device = torch.device(DEVICE)

# -------------------------------------
# Load Model
# -------------------------------------

model = DrowsinessCNN().to(device)

model.load_state_dict(
    torch.load(
        MODEL_PATH,
        map_location=device
    )
)

model.eval()

# -------------------------------------
# Image Transform
# -------------------------------------

transform = transforms.Compose([

    transforms.ToPILImage(),

    # Keep 3 channels because your CNN expects Conv2d(3,...)
    transforms.Grayscale(num_output_channels=3),

    transforms.Resize(IMAGE_SIZE),

    transforms.ToTensor(),
])

classes = [
    "awake",
    "sleepy"
]

# -------------------------------------
# Prediction Function
# -------------------------------------

def predict_eye(image):

    image = transform(image)

    image = image.unsqueeze(0).to(device)

    with torch.no_grad():

        outputs = model(image)

        probabilities = torch.softmax(outputs, dim=1)

        confidence, prediction = torch.max(
            probabilities,
            dim=1
        )

    return (
        classes[prediction.item()],
        confidence.item()
    )