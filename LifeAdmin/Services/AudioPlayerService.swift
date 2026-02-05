//
//  AudioPlayerService.swift
//  LifeAdmin
//
//  Manages audio playback for recorded files
//

import AVFoundation
import Foundation

@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying = false
    @Published var currentlyPlaying: URL?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
    }

    func play(url: URL) {
        // Stop any current playback
        stop()

        setupAudioSession()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            currentlyPlaying = url
            duration = audioPlayer?.duration ?? 0
            startTimer()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil

        isPlaying = false
        currentlyPlaying = nil
        currentTime = 0
        stopTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session for playback: \(error)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = self?.audioPlayer?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio decode error: \(error)")
        }
        Task { @MainActor in
            self.stop()
        }
    }
}
