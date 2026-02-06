//
//  AudioRecorderManager.swift
//  LifeAdmin Watch App
//
//  Manages audio recording on watchOS using AVFoundation
//

import AVFoundation
import WatchKit

@MainActor
class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    private var timer: Timer?
    private var currentRecordingURL: URL?

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func startRecording() {
        // Start extended runtime session to keep recording in background
        startExtendedRuntimeSession()

        let audioFilename = getDocumentsDirectory().appendingPathComponent(RecordingIdGenerator.generateFilename(for: .watch))
        currentRecordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0
            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil

        isRecording = false
        stopTimer()
        endExtendedRuntimeSession()

        // Save the recording to the store and sync to iPhone
        if let recordingURL = currentRecordingURL {
            // Save to persistent storage
            if let savedURL = WatchRecordingsStore.shared.addRecording(from: recordingURL) {
                // Send to iPhone with recording ID for checksum verification
                let recordingId = WatchRecordingsStore.shared.recordingIdFromURL(savedURL)
                PhoneSyncManager.shared.sendAudioFile(url: savedURL, recordingId: recordingId)
            }
            // Clean up the temporary recording file
            try? FileManager.default.removeItem(at: recordingURL)
        }

        currentRecordingURL = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startExtendedRuntimeSession() {
        extendedRuntimeSession = WKExtendedRuntimeSession()
        extendedRuntimeSession?.delegate = self
        extendedRuntimeSession?.start()
    }

    private func endExtendedRuntimeSession() {
        extendedRuntimeSession?.invalidate()
        extendedRuntimeSession = nil
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.stopRecording()
            }
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension AudioRecorderManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        if reason != .none {
            Task { @MainActor in
                if self.isRecording {
                    self.stopRecording()
                }
            }
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session started successfully
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session will expire soon, stop recording
        Task { @MainActor in
            if self.isRecording {
                self.stopRecording()
            }
        }
    }
}
