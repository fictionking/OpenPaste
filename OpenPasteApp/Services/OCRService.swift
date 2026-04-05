//
//  OCRService.swift
//  OpenPaste
//
//  Created by Claude on 2026-04-05.
//

import Vision
import AppKit

/// OCR服务 - 使用Vision框架从图片中提取文本
final class OCRService {

    // MARK: - Properties

    /// 支持的OCR语言
    private let recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"]

    /// 最大图片尺寸（超过此尺寸的图片会被缩小）
    private let maxImageSize: CGFloat = 4096

    // MARK: - Public Methods

    /// 从图片中提取文本（带进度回调）
    /// - Parameters:
    ///   - image: 要处理的图片
    ///   - progressHandler: 进度回调 (0.0 - 1.0)
    /// - Returns: (提取的文本, 检测到的语言)
    func extractText(from image: NSImage, progressHandler: ((Double) -> Void)?) async throws -> (text: String, language: String) {
        // 预处理图片（在autoreleasepool中管理内存）
        guard let ciImage = prepareImage(image) else {
            throw OCRError.imageProcessingFailed
        }

        // 创建OCR请求
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = recognitionLanguages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // 使用后台线程处理，但确保handler在同一线程创建和执行
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 在同一线程上创建handler并执行
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

                do {
                    // 更新进度
                    DispatchQueue.main.async {
                        progressHandler?(0.5)
                    }

                    try handler.perform([request])

                    guard let observations = request.results, !observations.isEmpty else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    // 合并所有识别结果
                    let text = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")

                    // 检测主要语言（简化版）
                    let detectedLanguage = self.detectLanguage(from: observations) ?? "zh-Hans"

                    DispatchQueue.main.async {
                        progressHandler?(1.0)
                    }

                    continuation.resume(returning: (text, detectedLanguage))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 准备图片（调整大小，转换格式）
    private func prepareImage(_ image: NSImage) -> CIImage? {
        // 如果图片太大，调整大小
        let needResize = image.size.width > maxImageSize || image.size.height > maxImageSize
        let processedImage = needResize ? resizeImage(image, max: maxImageSize) : image

        // 转换为CIImage
        guard let cgImage = processedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return CIImage(cgImage: cgImage)
    }

    /// 调整图片大小
    private func resizeImage(_ image: NSImage, max: CGFloat) -> NSImage {
        let ratio = min(max / image.size.width, max / image.size.height)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()

        return resized
    }

    /// 检测文本语言（简化实现）
    private func detectLanguage(from observations: [VNRecognizedTextObservation]) -> String? {
        // 简化实现：可以根据文本内容判断
        // 实际项目中可以使用更复杂的语言检测
        // 这里默认返回中文，因为主要用户是中文用户
        return "zh-Hans"
    }
}

/// OCR错误类型
enum OCRError: LocalizedError {
    case imageProcessingFailed
    case noTextFound
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return L10n.OCR.failed
        case .noTextFound:
            return L10n.OCR.noTextFound
        case .unsupportedFormat:
            return L10n.OCR.unsupportedFormat
        }
    }
}
