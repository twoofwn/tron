# Trốn (EscapeHatch)

Flutter prototype for preparing a simulated incoming call with a reusable dialogue scenario. This branch implements **screen 5 (Kho kịch bản)** and **screen 6 (Chi tiết kịch bản)** from the supplied mockup. A small entry page stands in for the unfinished combo editor.

## Run

```sh
flutter pub get
flutter run
```

Open **Mở kho kịch bản**. Search or filter scenarios, choose background sound, open a scenario, preview its dialogue, and press **Dùng kịch bản này**. The selection returns to the temporary combo draft on the entry page. Use `+` to create a personal scenario; **Sửa** edits a personal scenario, while **Sao chép** creates an editable copy of a bundled one. Personal scenarios and imported audio are stored in the app's documents directory.

## Demo audio

`assets/audio/voice/` contains synthetic Vietnamese speech generated with the macOS `Linh` voice. `assets/audio/ambient/` contains synthetic ambient loops. These are demo assets, not real recordings. Regenerate them on a Mac with `python3 tool/generate_demo_audio.py` if that voice is installed. To add your own audio, choose MP3, M4A, or WAV files in the app.

The preview pauses at each response marker until **Tiếp tục câu thoại** is tapped. Automatic voice activity detection and the simulated incoming call screens are outside this branch's scope.

## Check

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```
