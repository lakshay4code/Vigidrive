from pathlib import Path
import torch

# ==========================
# Project Directories
# ==========================

PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATASET_DIR = PROJECT_ROOT / "Datasets"   # Change to "dataset" if you rename the folder

TRAIN_DIR = DATASET_DIR / "train"
VAL_DIR = DATASET_DIR / "val"
TEST_DIR = DATASET_DIR / "test"

# ==========================
# Training Parameters
# ==========================

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
LEARNING_RATE = 0.001
EPOCHS = 10

NUM_CLASSES = 2
CLASS_NAMES = ["Awake", "Sleepy"]

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_PATH = PROJECT_ROOT / "models" / "best_model.pth"

NUM_WORKERS = 0

PIN_MEMORY = True