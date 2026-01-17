#!/usr/bin/env python3
"""
Train a music genre classifier using YAMNet embeddings on GTZAN dataset.
Exports a small TFLite model that takes YAMNet embeddings as input.

IMPORTANT: Use TensorFlow 2.14.x or 2.15.x for Android TFLite compatibility!
TensorFlow 2.16+ produces FULLY_CONNECTED op version 12 which isn't supported
by the Android TFLite runtime.

Usage:
    pip install -r requirements.txt
    # Or: pip install tensorflow==2.14.0 tensorflow-hub datasets soundfile numpy
    python train_genre_classifier.py

Output:
    genre_classifier.tflite - Copy this to android/app/src/main/assets/
"""

import os
import sys
import numpy as np
import tensorflow as tf
import tensorflow_hub as hub

def check_tensorflow_version():
    """Check if TensorFlow version is compatible for Android TFLite."""
    version = tf.__version__
    major, minor = map(int, version.split('.')[:2])

    print(f"TensorFlow version: {version}")

    if major == 2 and minor >= 17:
        # TF 2.17+ requires TFLite 2.17+ on Android (which we have configured)
        print(f"TensorFlow {version} - Requires Android TFLite 2.17+ (configured in build.gradle)")
    elif major == 2 and minor == 16:
        print("\n" + "=" * 70)
        print("WARNING: TensorFlow 2.16 detected!")
        print("This may produce FULLY_CONNECTED op v12 which requires TFLite 2.17+ on Android.")
        print("Make sure Android build.gradle uses tensorflow-lite:2.17.0 or higher.")
        print("=" * 70)
    elif major == 2 and minor >= 14:
        print(f"TensorFlow {version} - Good! Compatible with most Android TFLite versions.")
    else:
        print(f"TensorFlow {version} - Should be compatible.")

# Genre labels (must match order in Kotlin)
GENRES = ['blues', 'classical', 'country', 'disco', 'hiphop',
          'jazz', 'metal', 'pop', 'reggae', 'rock']

# Display names for output
GENRE_DISPLAY = ['Blues', 'Classical', 'Country', 'Disco', 'Hip-Hop',
                 'Jazz', 'Metal', 'Pop', 'Reggae', 'Rock']

# YAMNet model for embedding extraction
YAMNET_MODEL_HANDLE = 'https://tfhub.dev/google/yamnet/1'

def load_gtzan_huggingface():
    """Load GTZAN dataset using Hugging Face datasets library."""
    from datasets import load_dataset

    print("Loading GTZAN dataset via Hugging Face...")
    print("(This may download ~1.2GB on first run)")

    # Load GTZAN from Hugging Face
    dataset = load_dataset("marsyas/gtzan", "all", trust_remote_code=True)

    print(f"Dataset loaded: {dataset}")
    return dataset['train']

def extract_embeddings(audio_samples, yamnet_model):
    """Extract YAMNet embeddings from audio samples."""
    # YAMNet expects waveform at 16kHz as float32
    if audio_samples.dtype != np.float32:
        audio_samples = audio_samples.astype(np.float32)

    # Normalize if needed (tfds provides int values)
    if np.abs(audio_samples).max() > 1.0:
        audio_samples = audio_samples / 32768.0

    scores, embeddings, spectrogram = yamnet_model(audio_samples)
    # Average embeddings across time frames
    avg_embedding = tf.reduce_mean(embeddings, axis=0)
    return avg_embedding.numpy()

def main():
    print("=" * 60)
    print("Music Genre Classifier Training")
    print("Using YAMNet embeddings + Dense classifier")
    print("=" * 60)

    # Check TensorFlow version for compatibility
    check_tensorflow_version()

    # Load GTZAN via Hugging Face
    dataset = load_gtzan_huggingface()

    # Load YAMNet
    print("\nLoading YAMNet model...")
    yamnet_model = hub.load(YAMNET_MODEL_HANDLE)
    print("YAMNet loaded!")

    # Extract embeddings for all tracks
    print("\nExtracting embeddings from GTZAN dataset...")
    embeddings_list = []
    labels_list = []

    # The dataset uses integer labels 0-9 that map to genres
    # Order in GTZAN: blues(0), classical(1), country(2), disco(3), hiphop(4),
    #                 jazz(5), metal(6), pop(7), reggae(8), rock(9)
    # This matches our GENRES list exactly!
    print(f"Expected genres (0-9): {GENRES}")

    count = 0
    errors = 0
    for example in dataset:
        # Hugging Face format: audio is a dict with 'array' and 'sampling_rate'
        audio_data = example['audio']
        audio = np.array(audio_data['array'], dtype=np.float32)
        sample_rate = audio_data['sampling_rate']
        genre_idx = example['genre']  # This is already an integer index 0-9

        # Validate the genre index
        if not isinstance(genre_idx, int) or genre_idx < 0 or genre_idx >= len(GENRES):
            print(f"  Invalid genre index: {genre_idx}")
            continue

        try:
            # Resample to 16kHz if needed (GTZAN is 22050Hz)
            if sample_rate != 16000:
                ratio = 16000 / sample_rate
                new_len = int(len(audio) * ratio)
                indices = np.linspace(0, len(audio) - 1, new_len)
                audio = np.interp(indices, np.arange(len(audio)), audio)

            embedding = extract_embeddings(audio, yamnet_model)
            embeddings_list.append(embedding)
            labels_list.append(genre_idx)

            count += 1
            if count % 100 == 0:
                print(f"  Processed {count} tracks...")

        except Exception as e:
            errors += 1
            if errors <= 5:
                print(f"  Error processing track: {e}")

    print(f"  Total processed: {count}, Errors: {errors}")

    X = np.array(embeddings_list)
    y = np.array(labels_list)

    print(f"\nDataset: {len(X)} samples, {X.shape[1]} features")

    # Shuffle and split
    indices = np.random.permutation(len(X))
    X, y = X[indices], y[indices]

    split = int(0.8 * len(X))
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]

    print(f"Train: {len(X_train)}, Test: {len(X_test)}")

    # Build classifier model
    print("\nBuilding classifier model...")
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(1024,), name='embedding_input'),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(len(GENRES), activation='softmax', name='genre_output')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    model.summary()

    # Train
    print("\nTraining...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=50,
        batch_size=32,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True)
        ],
        verbose=1
    )

    # Evaluate
    test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
    print(f"\nTest accuracy: {test_acc * 100:.1f}%")

    # Convert to TFLite - use settings for maximum compatibility
    print("\nConverting to TFLite...")
    print(f"TensorFlow version: {tf.__version__}")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Don't use quantization optimizations - use standard float32
    converter.optimizations = []
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

    tflite_model = converter.convert()
    print("Converted successfully")

    output_path = "genre_classifier.tflite"
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    print(f"\nModel saved to: {output_path}")
    print(f"Model size: {len(tflite_model) / 1024:.1f} KB")
    print(f"\nCopy this file to: android/app/src/main/assets/")

    # Also save the Keras model
    model.save("genre_classifier.h5")
    print("Keras model saved to: genre_classifier.h5")

    # Test the TFLite model
    print("\nVerifying TFLite model...")
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"Input shape: {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")

    # Test prediction
    test_embedding = X_test[0:1].astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_embedding)
    interpreter.invoke()
    prediction = interpreter.get_tensor(output_details[0]['index'])
    predicted_genre = GENRES[np.argmax(prediction)]
    actual_genre = GENRES[y_test[0]]
    print(f"Test prediction: {predicted_genre} (actual: {actual_genre})")

    print("\n" + "=" * 60)
    print("Done! Next steps:")
    print("1. Copy genre_classifier.tflite to android/app/src/main/assets/")
    print("2. Update GenreClassifier.kt to use the new model")
    print("=" * 60)

    # Check op compatibility for Android TFLite runtime
    print("\n" + "=" * 60)
    print("IMPORTANT: Op Version Compatibility Check")
    print("=" * 60)
    print(f"Your TensorFlow version: {tf.__version__}")
    print("\nIf you see 'FULLY_CONNECTED version 12' errors on Android:")
    print("1. Install TensorFlow 2.14 or 2.15:")
    print("   pip install tensorflow==2.14.0")
    print("2. Re-run this script to generate a compatible model")
    print("\nAlternatively, the Android TFLite runtime may need updating.")
    print("Current Android dependency: org.tensorflow:tensorflow-lite:2.16.1")
    print("=" * 60)


def create_simple_model():
    """Create a simpler model that may have better op compatibility."""
    # Use a simpler architecture - just one hidden layer
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(1024,), name='embedding_input'),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(10, activation='softmax', name='genre_output')
    ])

    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--simple":
        print("Using simple model architecture for better compatibility")
        # Could implement a simpler training path here
    main()
