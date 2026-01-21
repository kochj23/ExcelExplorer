import Foundation
import AppKit

//
//  ImageGenerationService.swift
//  Shared Image Generation Service
//
//  Uses ComfyUI, SwarmUI, or Automatic1111 for AI image generation
//  Author: Jordan Koch
//  Date: 2026-01-21
//

/// Shared image generation service for AI-enabled projects
/// Supports: ComfyUI, SwarmUI, Automatic1111, OpenAI DALL-E
class ImageGenerationService: ObservableObject {

    // MARK: - Published Properties

    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var lastError: String?
    @Published var generatedImages: [GeneratedImage] = []

    // MARK: - Properties

    private let aiBackend = AIBackendManager.shared

    // MARK: - Image Generation

    /// Generate image from text prompt
    func generateImage(
        prompt: String,
        style: ImageStyle = .realistic,
        size: ImageSize = .square1024
    ) async throws -> NSImage {

        await MainActor.run {
            isGenerating = true
            progress = 0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isGenerating = false
                progress = 0
            }
        }

        // Determine which backend to use (prefer ComfyUI as most reliable)
        if aiBackend.isComfyUIAvailable {
            return try await generateWithComfyUI(prompt: prompt, style: style, size: size)
        } else if aiBackend.isAutomatic1111Available {
            return try await generateWithAutomatic1111(prompt: prompt, style: style, size: size)
        } else if aiBackend.isSwarmUIAvailable {
            return try await generateWithSwarmUI(prompt: prompt, style: style, size: size)
        } else {
            throw ImageGenerationError.noBackendAvailable
        }
    }

    // MARK: - SwarmUI Implementation

    private func generateWithSwarmUI(
        prompt: String,
        style: ImageStyle,
        size: ImageSize
    ) async throws -> NSImage {

        await updateProgress(0.1)

        let enhancedPrompt = enhancePrompt(prompt, style: style)

        guard let url = URL(string: "\(aiBackend.swarmUIServerURL)/API/GenerateText2Image") else {
            throw ImageGenerationError.invalidURL
        }

        let requestBody: [String: Any] = [
            "prompt": enhancedPrompt,
            "model": "Flux/flux1-schnell-fp8",
            "width": size.width,
            "height": size.height,
            "cfgscale": 1.0,
            "steps": 6,
            "seed": -1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120.0

        await updateProgress(0.3)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        await updateProgress(0.7)

        guard httpResponse.statusCode == 200 else {
            throw ImageGenerationError.httpError(httpResponse.statusCode)
        }

        struct SwarmUIResponse: Codable {
            let images: [String] // Base64 encoded images
        }

        let swarmResponse = try JSONDecoder().decode(SwarmUIResponse.self, from: data)

        guard let imageBase64 = swarmResponse.images.first,
              let imageData = Data(base64Encoded: imageBase64),
              let image = NSImage(data: imageData) else {
            throw ImageGenerationError.noImageGenerated
        }

        await updateProgress(1.0)

        // Save to generated images
        let generated = GeneratedImage(image: image, prompt: prompt, style: style, backend: "SwarmUI")
        await MainActor.run {
            generatedImages.insert(generated, at: 0)
        }

        return image
    }

    // MARK: - ComfyUI Implementation

    private func generateWithComfyUI(
        prompt: String,
        style: ImageStyle,
        size: ImageSize
    ) async throws -> NSImage {

        await updateProgress(0.1)

        let enhancedPrompt = enhancePrompt(prompt, style: style)

        // ComfyUI uses workflow-based API
        // Create a simple text2img workflow
        let workflow: [String: Any] = [
            "3": [
                "inputs": [
                    "seed": Int.random(in: 0...999999999),
                    "steps": 20,
                    "cfg": 7.0,
                    "sampler_name": "euler",
                    "scheduler": "normal",
                    "denoise": 1.0,
                    "model": ["4", 0],
                    "positive": ["6", 0],
                    "negative": ["7", 0],
                    "latent_image": ["5", 0]
                ],
                "class_type": "KSampler"
            ],
            "4": [
                "inputs": [
                    "ckpt_name": "sd_xl_base_1.0.safetensors"
                ],
                "class_type": "CheckpointLoaderSimple"
            ],
            "5": [
                "inputs": [
                    "width": size.width,
                    "height": size.height,
                    "batch_size": 1
                ],
                "class_type": "EmptyLatentImage"
            ],
            "6": [
                "inputs": [
                    "text": enhancedPrompt,
                    "clip": ["4", 1]
                ],
                "class_type": "CLIPTextEncode"
            ],
            "7": [
                "inputs": [
                    "text": "text, watermark, blurry, low quality, distorted",
                    "clip": ["4", 1]
                ],
                "class_type": "CLIPTextEncode"
            ],
            "8": [
                "inputs": [
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                ],
                "class_type": "VAEDecode"
            ],
            "9": [
                "inputs": [
                    "filename_prefix": "ExcelExplorer",
                    "images": ["8", 0]
                ],
                "class_type": "SaveImage"
            ]
        ]

        // Submit workflow
        guard let url = URL(string: "\(aiBackend.comfyUIServerURL)/prompt") else {
            throw ImageGenerationError.invalidURL
        }

        let requestBody: [String: Any] = [
            "prompt": workflow,
            "client_id": UUID().uuidString
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120.0

        await updateProgress(0.3)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to get error details from response
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("ComfyUI Error Details: \(message)")
            } else if let errorString = String(data: data, encoding: .utf8) {
                print("ComfyUI Error Response: \(errorString)")
            }
            throw ImageGenerationError.httpError(httpResponse.statusCode)
        }

        // Parse response to get prompt ID
        struct ComfyPromptResponse: Codable {
            let prompt_id: String
        }

        let promptResponse = try JSONDecoder().decode(ComfyPromptResponse.self, from: data)

        // Wait for image generation (poll for completion)
        await updateProgress(0.5)

        var attempts = 0
        while attempts < 60 { // Wait up to 60 seconds
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Check history for our prompt
            guard let historyURL = URL(string: "\(aiBackend.comfyUIServerURL)/history/\(promptResponse.prompt_id)") else {
                throw ImageGenerationError.invalidURL
            }

            let (historyData, _) = try await URLSession.shared.data(from: historyURL)

            if let historyDict = try? JSONSerialization.jsonObject(with: historyData) as? [String: Any],
               let promptHistory = historyDict[promptResponse.prompt_id] as? [String: Any],
               let outputs = promptHistory["outputs"] as? [String: Any],
               let saveImageOutput = outputs["9"] as? [String: Any],
               let images = saveImageOutput["images"] as? [[String: Any]],
               let firstImage = images.first,
               let filename = firstImage["filename"] as? String {

                // Download the image
                guard let imageURL = URL(string: "\(aiBackend.comfyUIServerURL)/view?filename=\(filename)&subfolder=&type=output") else {
                    throw ImageGenerationError.invalidURL
                }

                await updateProgress(0.9)

                let (imageData, _) = try await URLSession.shared.data(from: imageURL)

                guard let image = NSImage(data: imageData) else {
                    throw ImageGenerationError.noImageGenerated
                }

                await updateProgress(1.0)

                // Save to generated images
                let generated = GeneratedImage(image: image, prompt: prompt, style: style, backend: "ComfyUI")
                await MainActor.run {
                    generatedImages.insert(generated, at: 0)
                }

                return image
            }

            attempts += 1
            await updateProgress(0.5 + (Double(attempts) / 120.0)) // Show progress
        }

        throw ImageGenerationError.timeout
    }

    // MARK: - Automatic1111 Implementation

    private func generateWithAutomatic1111(
        prompt: String,
        style: ImageStyle,
        size: ImageSize
    ) async throws -> NSImage {

        await updateProgress(0.1)

        let enhancedPrompt = enhancePrompt(prompt, style: style)

        guard let url = URL(string: "\(aiBackend.automatic1111ServerURL)/sdapi/v1/txt2img") else {
            throw ImageGenerationError.invalidURL
        }

        let requestBody: [String: Any] = [
            "prompt": enhancedPrompt,
            "negative_prompt": "blurry, low quality, distorted, ugly",
            "steps": 20,
            "cfg_scale": 7.0,
            "width": size.width,
            "height": size.height,
            "seed": -1,
            "sampler_name": "Euler a"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120.0

        await updateProgress(0.3)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        await updateProgress(0.7)

        guard httpResponse.statusCode == 200 else {
            throw ImageGenerationError.httpError(httpResponse.statusCode)
        }

        struct A1111Response: Codable {
            let images: [String] // Base64 encoded
        }

        let a1111Response = try JSONDecoder().decode(A1111Response.self, from: data)

        guard let imageBase64 = a1111Response.images.first,
              let imageData = Data(base64Encoded: imageBase64),
              let image = NSImage(data: imageData) else {
            throw ImageGenerationError.noImageGenerated
        }

        await updateProgress(1.0)

        let generated = GeneratedImage(image: image, prompt: prompt, style: style, backend: "Automatic1111")
        await MainActor.run {
            generatedImages.insert(generated, at: 0)
        }

        return image
    }

    // MARK: - Prompt Enhancement

    private func enhancePrompt(_ prompt: String, style: ImageStyle) -> String {
        var enhanced = prompt

        // Add style-specific keywords
        switch style {
        case .realistic:
            enhanced += ", photorealistic, high detail, professional photography"
        case .artistic:
            enhanced += ", digital art, artistic, painterly style"
        case .fantasy:
            enhanced += ", fantasy art, magical atmosphere, epic"
        case .pixelArt:
            enhanced += ", pixel art style, retro gaming aesthetic, 16-bit"
        case .cartoon:
            enhanced += ", cartoon style, vibrant colors, illustrated"
        case .anime:
            enhanced += ", anime art style, manga aesthetic"
        }

        // Add quality keywords
        enhanced += ", 4K, high quality, detailed"

        return enhanced
    }

    // MARK: - Helper

    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            progress = value
        }
    }
}

// MARK: - Models

struct GeneratedImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let prompt: String
    let style: ImageStyle
    let backend: String
    let timestamp = Date()
}

enum ImageStyle: String, CaseIterable {
    case realistic = "Realistic"
    case artistic = "Artistic"
    case fantasy = "Fantasy"
    case pixelArt = "Pixel Art"
    case cartoon = "Cartoon"
    case anime = "Anime"
}

enum ImageSize {
    case square512
    case square1024
    case portrait
    case landscape

    var width: Int {
        switch self {
        case .square512: return 512
        case .square1024: return 1024
        case .portrait: return 768
        case .landscape: return 1024
        }
    }

    var height: Int {
        switch self {
        case .square512: return 512
        case .square1024: return 1024
        case .portrait: return 1024
        case .landscape: return 768
        }
    }
}

enum ImageGenerationError: LocalizedError {
    case noBackendAvailable
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noImageGenerated
    case notImplemented(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "No image generation backend available. Please start ComfyUI, SwarmUI, or Automatic1111."
        case .invalidURL:
            return "Invalid backend URL configuration"
        case .invalidResponse:
            return "Received invalid response from image backend"
        case .timeout:
            return "Image generation timed out after 60 seconds. The backend may be busy or the prompt may be too complex."
        case .httpError(let code):
            return "HTTP error \(code) from image backend"
        case .noImageGenerated:
            return "No image was generated"
        case .notImplemented(let message):
            return message
        }
    }
}
