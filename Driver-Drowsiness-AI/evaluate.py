import os
import numpy as np
import torch
import matplotlib.pyplot as plt

from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report,
    ConfusionMatrixDisplay,
    roc_curve,
    auc,
    precision_recall_curve
)

from src.model import DrowsinessCNN
from src.dataset import test_loader
from src.config import *

# =====================================================
# Device
# =====================================================

device = torch.device(DEVICE)

# =====================================================
# Load Model
# =====================================================

model = DrowsinessCNN().to(device)

model.load_state_dict(
    torch.load(
        MODEL_PATH,
        map_location=device
    )
)

model.eval()

# =====================================================
# Lists
# =====================================================

all_labels = []

all_predictions = []

all_probabilities = []

# =====================================================
# Evaluation
# =====================================================

with torch.no_grad():

    for images, labels in test_loader:

        images = images.to(device)

        labels = labels.to(device)

        outputs = model(images)

        probabilities = torch.softmax(outputs, dim=1)

        confidence, predictions = torch.max(
            probabilities,
            dim=1
        )

        all_labels.extend(
            labels.cpu().numpy()
        )

        all_predictions.extend(
            predictions.cpu().numpy()
        )

        all_probabilities.extend(
            probabilities[:,1].cpu().numpy()
        )

# =====================================================
# Metrics
# =====================================================

accuracy = accuracy_score(
    all_labels,
    all_predictions
)

precision = precision_score(
    all_labels,
    all_predictions
)

recall = recall_score(
    all_labels,
    all_predictions
)

f1 = f1_score(
    all_labels,
    all_predictions
)

print("="*60)

print("MODEL EVALUATION")

print("="*60)

print(f"Accuracy  : {accuracy:.4f}")

print(f"Precision : {precision:.4f}")

print(f"Recall    : {recall:.4f}")

print(f"F1 Score  : {f1:.4f}")

print()

print(classification_report(
    all_labels,
    all_predictions,
    target_names=CLASS_NAMES
))

# =====================================================
# Save Folder
# =====================================================

os.makedirs(
    "evaluation_results",
    exist_ok=True
)

with open(
    "evaluation_results/metrics.txt",
    "w"
) as file:

    file.write("="*60+"\n")

    file.write("MODEL EVALUATION\n")

    file.write("="*60+"\n\n")

    file.write(f"Accuracy : {accuracy:.4f}\n")

    file.write(f"Precision : {precision:.4f}\n")

    file.write(f"Recall : {recall:.4f}\n")

    file.write(f"F1 Score : {f1:.4f}\n\n")

    file.write(
        classification_report(
            all_labels,
            all_predictions,
            target_names=CLASS_NAMES
        )
    )
    # =====================================================
# Confusion Matrix
# =====================================================

cm = confusion_matrix(
    all_labels,
    all_predictions
)

disp = ConfusionMatrixDisplay(
    confusion_matrix=cm,
    display_labels=CLASS_NAMES
)

fig, ax = plt.subplots(figsize=(6, 6))

disp.plot(
    ax=ax,
    cmap="Blues",
    colorbar=False
)

plt.title("Confusion Matrix")

plt.tight_layout()

plt.savefig(
    "evaluation_results/confusion_matrix.png",
    dpi=300
)

plt.close()

# =====================================================
# ROC Curve
# =====================================================

fpr, tpr, thresholds = roc_curve(
    all_labels,
    all_probabilities
)

roc_auc = auc(
    fpr,
    tpr
)

plt.figure(figsize=(7,6))

plt.plot(
    fpr,
    tpr,
    linewidth=2,
    label=f"AUC = {roc_auc:.4f}"
)

plt.plot(
    [0,1],
    [0,1],
    linestyle="--"
)

plt.xlabel("False Positive Rate")

plt.ylabel("True Positive Rate")

plt.title("ROC Curve")

plt.legend()

plt.grid(True)

plt.tight_layout()

plt.savefig(
    "evaluation_results/roc_curve.png",
    dpi=300
)

plt.close()

# =====================================================
# Precision Recall Curve
# =====================================================

precision_curve, recall_curve, thresholds = precision_recall_curve(
    all_labels,
    all_probabilities
)

plt.figure(figsize=(7,6))

plt.plot(
    recall_curve,
    precision_curve,
    linewidth=2
)

plt.xlabel("Recall")

plt.ylabel("Precision")

plt.title("Precision-Recall Curve")

plt.grid(True)

plt.tight_layout()

plt.savefig(
    "evaluation_results/precision_recall_curve.png",
    dpi=300
)

plt.close()

# =====================================================
# Final Output
# =====================================================

print()

print("=" * 60)
print("Evaluation Complete")
print("=" * 60)

print(f"Accuracy  : {accuracy:.4f}")
print(f"Precision : {precision:.4f}")
print(f"Recall    : {recall:.4f}")
print(f"F1 Score  : {f1:.4f}")
print(f"AUC Score : {roc_auc:.4f}")

print()

print("Files saved in evaluation_results/")

print("✓ metrics.txt")
print("✓ confusion_matrix.png")
print("✓ roc_curve.png")
print("✓ precision_recall_curve.png")