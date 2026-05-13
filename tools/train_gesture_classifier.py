#!/usr/bin/env python3
"""
Blink-to-Speak Gesture Classifier — Training Script
=====================================================
Generates synthetic training data, trains a 1D-CNN on it,
and exports a TFLite model for on-device inference.

Features per frame (6 total):
  [eyeOpenProbLeft, eyeOpenProbRight, gazeX, gazeY, irisVelocityX, irisVelocityY]

Classes (5):
  0: neutral   — eyes open, gaze stable
  1: blink     — both eyes dip and reopen quickly (~8-12 frames)
  2: shut      — both eyes stay closed for >15 frames
  3: wink_L    — left eye closes, right stays open
  4: wink_R    — right eye closes, left stays open

Usage:
  python train_gesture_classifier.py

Output:
  gesture_classifier.tflite  (copy to assets/models/)
  training_report.txt
"""

import os
import json
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix

# ── Config ─────────────────────────────────────────────────────────────────────
WINDOW_SIZE    = 15          # frames per example
N_FEATURES     = 6           # features per frame
N_CLASSES      = 5
N_SYNTHETIC    = 8000        # synthetic examples per class
REAL_DATA_DIR  = 'blink_recordings'   # drop JSON recordings here
BATCH_SIZE     = 64
EPOCHS         = 60
MODEL_OUT      = '../assets/models/gesture_classifier.tflite'
REPORT_OUT     = 'training_report.txt'

os.makedirs('../assets/models', exist_ok=True)

np.random.seed(42)
tf.random.set_seed(42)

# ── Synthetic data generation ──────────────────────────────────────────────────

def _noise(n, scale=0.03):
    return np.random.normal(0, scale, n)

def _gaze_walk(n, scale=0.04):
    """Slow random walk for gaze — realistic neutral eye movement."""
    walk = np.cumsum(np.random.normal(0, scale, n))
    return np.clip(walk - walk.mean(), -0.4, 0.4)

def _iris_vel(pos):
    """Finite-difference iris velocity from position series."""
    vel = np.diff(pos, prepend=pos[0])
    return np.clip(vel, -0.5, 0.5)

def generate_neutral():
    L = 0.88 + _noise(WINDOW_SIZE, 0.04)
    R = 0.88 + _noise(WINDOW_SIZE, 0.04)
    gx = _gaze_walk(WINDOW_SIZE, 0.03)
    gy = _gaze_walk(WINDOW_SIZE, 0.02)
    ivx = _iris_vel(gx)
    ivy = _iris_vel(gy)
    return np.stack([L, R, gx, gy, ivx, ivy], axis=1)

def _blink_curve(peak_frame, width=4, depth=0.03):
    """Gaussian dip for one eye closing and reopening."""
    t = np.arange(WINDOW_SIZE)
    dip = 1.0 - (1.0 - depth) * np.exp(-0.5 * ((t - peak_frame) / width) ** 2)
    return np.clip(dip, 0.0, 1.0)

def generate_blink():
    peak = np.random.randint(5, WINDOW_SIZE - 5)
    width = np.random.uniform(2.5, 4.5)
    depth = np.random.uniform(0.01, 0.06)
    curve = _blink_curve(peak, width, depth)
    L = curve + _noise(WINDOW_SIZE, 0.025)
    R = curve + _noise(WINDOW_SIZE, 0.025)
    gx = _gaze_walk(WINDOW_SIZE)
    gy = _gaze_walk(WINDOW_SIZE)
    ivx = _iris_vel(gx)
    ivy = _iris_vel(gy)
    return np.stack([np.clip(L, 0, 1), np.clip(R, 0, 1), gx, gy, ivx, ivy], axis=1)

def generate_shut():
    """Both eyes stay closed for most of the window."""
    stay_closed = np.random.randint(10, WINDOW_SIZE)
    start = np.random.randint(0, WINDOW_SIZE - stay_closed)
    L = 0.88 * np.ones(WINDOW_SIZE)
    L[start:start + stay_closed] = 0.04 + _noise(stay_closed, 0.02)
    R = 0.88 * np.ones(WINDOW_SIZE)
    R[start:start + stay_closed] = 0.04 + _noise(stay_closed, 0.02)
    gx = _gaze_walk(WINDOW_SIZE, 0.01)
    gy = _gaze_walk(WINDOW_SIZE, 0.01)
    ivx = _iris_vel(gx)
    ivy = _iris_vel(gy)
    return np.stack([np.clip(L, 0, 1), np.clip(R, 0, 1), gx, gy, ivx, ivy], axis=1)

def generate_wink(left=True):
    """One eye closes, the other stays open throughout."""
    peak = np.random.randint(4, WINDOW_SIZE - 4)
    width = np.random.uniform(2.5, 4.5)
    depth = np.random.uniform(0.01, 0.06)
    closed_eye = _blink_curve(peak, width, depth) + _noise(WINDOW_SIZE, 0.025)
    open_eye = 0.88 + _noise(WINDOW_SIZE, 0.03)
    gx = _gaze_walk(WINDOW_SIZE)
    gy = _gaze_walk(WINDOW_SIZE)
    ivx = _iris_vel(gx)
    ivy = _iris_vel(gy)
    if left:
        L, R = closed_eye, open_eye
    else:
        L, R = open_eye, closed_eye
    return np.stack([np.clip(L, 0, 1), np.clip(R, 0, 1), gx, gy, ivx, ivy], axis=1)

def generate_synthetic(n_per_class):
    generators = [
        (generate_neutral, 0),
        (generate_blink,   1),
        (generate_shut,    2),
        (lambda: generate_wink(left=True),  3),
        (lambda: generate_wink(left=False), 4),
    ]
    X, y = [], []
    for gen_fn, label in generators:
        for _ in range(n_per_class):
            X.append(gen_fn())
            y.append(label)
    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32)

# ── Real data loader ───────────────────────────────────────────────────────────

CLASS_MAP = {'neutral': 0, 'blink': 1, 'shut': 2, 'wink_L': 3, 'wink_R': 4}

def load_real_data(data_dir):
    """Load labeled JSON recordings exported by the Flutter GestureRecorder."""
    X, y = [], []
    if not os.path.exists(data_dir):
        print(f'[INFO] No real data directory found at {data_dir!r}. Using synthetic only.')
        return np.empty((0, WINDOW_SIZE, N_FEATURES), dtype=np.float32), np.empty(0, dtype=np.int32)

    files = [f for f in os.listdir(data_dir) if f.endswith('.json')]
    print(f'[INFO] Found {len(files)} recording file(s) in {data_dir!r}')
    for fname in files:
        with open(os.path.join(data_dir, fname)) as f:
            data = json.load(f)
        for ex in data.get('examples', []):
            label_str = ex.get('label', 'neutral')
            label = CLASS_MAP.get(label_str, 0)
            frames = ex.get('frames', [])
            if len(frames) < WINDOW_SIZE:
                continue
            # Take the last WINDOW_SIZE frames (most recent before event)
            window = frames[-WINDOW_SIZE:]
            vec = [[
                f['eyeOpenProbLeft'], f['eyeOpenProbRight'],
                f['gazeX'], f['gazeY'],
                f['irisVX'], f['irisVY'],
            ] for f in window]
            X.append(vec)
            y.append(label)
    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32)

# ── Model definition ───────────────────────────────────────────────────────────

def build_model():
    inp = tf.keras.Input(shape=(WINDOW_SIZE, N_FEATURES), name='input')
    x = tf.keras.layers.Conv1D(32, kernel_size=3, padding='same', activation='relu')(inp)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Conv1D(64, kernel_size=3, padding='same', activation='relu')(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Conv1D(64, kernel_size=3, padding='same', activation='relu')(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(48, activation='relu')(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    out = tf.keras.layers.Dense(N_CLASSES, activation='softmax', name='output')(x)
    model = tf.keras.Model(inp, out)
    return model

# ── TFLite export ──────────────────────────────────────────────────────────────

def export_tflite(model, X_calib, out_path):
    """Export full int8-quantized TFLite model."""
    def representative_dataset():
        idxs = np.random.choice(len(X_calib), min(200, len(X_calib)), replace=False)
        for i in idxs:
            yield [X_calib[i:i+1]]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type  = tf.float32
    converter.inference_output_type = tf.float32

    tflite_model = converter.convert()
    with open(out_path, 'wb') as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    print(f'\n[OK] TFLite model saved -> {out_path}  ({size_kb:.1f} KB)')
    return size_kb

# -- Main -----------------------------------------------------------------------

def main():
    print('=' * 60)
    print('Blink-to-Speak Gesture Classifier Training')
    print('=' * 60)

    # 1. Generate synthetic data
    print(f'\n[1] Generating {N_SYNTHETIC} synthetic examples per class...')
    X_syn, y_syn = generate_synthetic(N_SYNTHETIC)
    print(f'    Synthetic dataset: {X_syn.shape}')

    # 2. Load real data (if available)
    print('\n[2] Loading real recordings...')
    X_real, y_real = load_real_data(REAL_DATA_DIR)
    print(f'    Real dataset: {X_real.shape}')

    # 3. Combine
    if len(X_real) > 0:
        # Real data is worth 5x synthetic during mixing (up-weight)
        X_real_up = np.repeat(X_real, 5, axis=0)
        y_real_up = np.repeat(y_real, 5, axis=0)
        X_all = np.concatenate([X_syn, X_real_up], axis=0)
        y_all = np.concatenate([y_syn, y_real_up], axis=0)
    else:
        X_all, y_all = X_syn, y_syn

    # Shuffle
    perm = np.random.permutation(len(X_all))
    X_all, y_all = X_all[perm], y_all[perm]

    print(f'\n[3] Total training examples: {len(X_all)}')
    for cls_idx, cls_name in enumerate(['neutral', 'blink', 'shut', 'wink_L', 'wink_R']):
        n = (y_all == cls_idx).sum()
        print(f'    {cls_name:10s}: {n}')

    # 4. Split
    X_train, X_val, y_train, y_val = train_test_split(
        X_all, y_all, test_size=0.15, stratify=y_all, random_state=42
    )

    # 5. Build and train
    print(f'\n[4] Building model...')
    model = build_model()
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy', patience=10, restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=5, min_lr=1e-5
        ),
    ]

    print(f'\n[5] Training for up to {EPOCHS} epochs...')
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        batch_size=BATCH_SIZE,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1,
    )

    # 6. Evaluate
    print('\n[6] Evaluation on validation set:')
    CLASS_NAMES = ['neutral', 'blink', 'shut', 'wink_L', 'wink_R']
    y_pred = np.argmax(model.predict(X_val, verbose=0), axis=1)
    report = classification_report(y_val, y_pred, target_names=CLASS_NAMES, digits=3)
    cm = confusion_matrix(y_val, y_pred)
    print(report)
    print('Confusion matrix:')
    print(cm)

    # 7. Export TFLite
    print('\n[7] Exporting TFLite model...')
    size_kb = export_tflite(model, X_train, MODEL_OUT)

    # 8. Write report
    with open(REPORT_OUT, 'w', encoding='utf-8') as f:
        f.write('Blink-to-Speak Gesture Classifier - Training Report\n')
        f.write('=' * 60 + '\n\n')
        f.write(f'Training examples: {len(X_train)}\n')
        f.write(f'Validation examples: {len(X_val)}\n')
        f.write(f'Real data examples: {len(X_real)}\n\n')
        f.write(report)
        f.write('\nConfusion matrix:\n')
        f.write(str(cm))
        f.write(f'\n\nModel size: {size_kb:.1f} KB\n')

    print(f'\n[OK] Done! Copy {MODEL_OUT} into your Flutter project.')
    print(f'    Report saved to {REPORT_OUT}')
    print('\nNext step: flutter pub add tflite_flutter, rebuild, test on device.')

if __name__ == '__main__':
    main()
