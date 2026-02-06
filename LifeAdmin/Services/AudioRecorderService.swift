//
//  AudioRecorderService.swift
//  LifeAdmin
//
//  Manages audio recording on iOS using AVFoundation
//

import AVFoundation
import Foundation

@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    static let shared = AudioRecorderService()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var permissionGranted = false

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentRecordingURL: URL?

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
        case .undetermined:
            requestPermission()
        @unknown default:
            permissionGranted = false
        }
    }

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.permissionGranted = granted
            }
        }
    }

    func startRecording() {
        guard permissionGranted else {
            requestPermission()
            return
        }

        setupAudioSession()

        let audioFilename = getAudioDirectory().appendingPathComponent(RecordingIdGenerator.generateFilename(for: .iphone))
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
        deactivateAudioSession()

        // Notify that a new recording is available
        if let recordingURL = currentRecordingURL {
            NotificationCenter.default.post(
                name: .newRecordingAvailable,
                object: nil,
                userInfo: ["url": recordingURL]
            )
        }

        currentRecordingURL = nil
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
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

    private func getAudioDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsDirectory.appendingPathComponent("AudioRecordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        return audioDirectory
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.stopRecording()
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
        Task { @MainActor in
            self.stopRecording()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newRecordingAvailable = Notification.Name("newRecordingAvailable")
}
