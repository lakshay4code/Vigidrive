import torch
import torch.nn as nn
import torch.optim as optim

from tqdm import tqdm

from src.model import DrowsinessCNN
from src.dataset import train_loader, val_loader
from src.config import *

device = torch.device(DEVICE)

print(f"\nUsing Device : {device}\n")

model = DrowsinessCNN().to(device)

criterion = nn.CrossEntropyLoss()

optimizer = optim.Adam(
    model.parameters(),
    lr=LEARNING_RATE
)

best_accuracy = 0.0

for epoch in range(EPOCHS):

    print(f"\nEpoch {epoch+1}/{EPOCHS}")

    ##################################
    # TRAINING
    ##################################

    model.train()

    running_loss = 0
    correct = 0
    total = 0

    progress_bar = tqdm(train_loader)

    for images, labels in progress_bar:

        images = images.to(device)
        labels = labels.to(device)

        optimizer.zero_grad()

        outputs = model(images)

        loss = criterion(outputs, labels)

        loss.backward()

        optimizer.step()

        running_loss += loss.item()

        _, predicted = torch.max(outputs, 1)

        total += labels.size(0)

        correct += (predicted == labels).sum().item()

        progress_bar.set_description(
            f"Loss {running_loss/(total/BATCH_SIZE):.4f}"
        )

    train_accuracy = 100 * correct / total

    ##################################
    # VALIDATION
    ##################################

    model.eval()

    val_correct = 0
    val_total = 0
    val_loss = 0

    with torch.no_grad():

        for images, labels in val_loader:

            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)

            loss = criterion(outputs, labels)

            val_loss += loss.item()

            _, predicted = torch.max(outputs, 1)

            val_total += labels.size(0)

            val_correct += (predicted == labels).sum().item()

    val_accuracy = 100 * val_correct / val_total

    print(f"\nTraining Accuracy : {train_accuracy:.2f}%")
    print(f"Validation Accuracy : {val_accuracy:.2f}%")

    print(f"Training Loss : {running_loss/len(train_loader):.4f}")
    print(f"Validation Loss : {val_loss/len(val_loader):.4f}")

    ##################################
    # SAVE BEST MODEL
    ##################################

    if val_accuracy > best_accuracy:

        best_accuracy = val_accuracy

        torch.save(model.state_dict(), MODEL_PATH)

        print("\n✅ Best Model Saved!")