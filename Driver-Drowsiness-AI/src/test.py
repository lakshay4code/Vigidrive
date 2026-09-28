import torch
import torch.nn as nn

from src.model import DrowsinessCNN
from src.dataset import test_loader
from src.config import *

device = torch.device(DEVICE)

# Load model
model = DrowsinessCNN().to(device)
model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
model.eval()

criterion = nn.CrossEntropyLoss()

correct = 0
total = 0
test_loss = 0

with torch.no_grad():

    for images, labels in test_loader:

        images = images.to(device)
        labels = labels.to(device)

        outputs = model(images)

        loss = criterion(outputs, labels)

        test_loss += loss.item()

        _, predicted = torch.max(outputs, 1)

        total += labels.size(0)

        correct += (predicted == labels).sum().item()

accuracy = 100 * correct / total

print("\n========== TEST RESULTS ==========")
print(f"Test Accuracy : {accuracy:.2f}%")
print(f"Test Loss     : {test_loss/len(test_loader):.4f}")