/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import CoreML
import Vision

class CreateQuoteViewController: UIViewController {
    // MARK: - Properties
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var quoteTextView: UITextView!
    @IBOutlet weak var addStickerButton: UIBarButtonItem!
    @IBOutlet weak var stickerView: UIView!
    @IBOutlet weak var starterLabel: UILabel!
    
    var drawingView: DrawingView!
    
    private lazy var quoteList: [Quote] = {
        guard let path = Bundle.main.path(forResource: "Quotes", ofType: "plist")
        else {
            print("Failed to read Quotes.plist")
            return []
        }
        let fileUrl = URL.init(fileURLWithPath: path)
        guard let quotesArray = NSArray(contentsOf: fileUrl) as? [Dictionary<String, Any>]
        else { return [] }
        let quotes: [Quote] = quotesArray.compactMap { (quote) in
            guard
                let text = quote[Quote.Key.text] as? String,
                let author = quote[Quote.Key.author] as? String,
                let keywords = quote[Quote.Key.keywords] as? [String]
            else { return nil }
            
            return Quote(
                text: text,
                author: author,
                keywords: keywords)
        }
        return quotes
    }()
    
    private lazy var stickerFrame: CGRect = {
        let stickerHeightWidth = 50.0
        let stickerOffsetX =
            Double(stickerView.bounds.midX) - (stickerHeightWidth / 2.0)
        let stickerRect = CGRect(
            x: stickerOffsetX,
            y: 80.0, width:
                stickerHeightWidth,
            height: stickerHeightWidth)
        return stickerRect
    }()
    
    private lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let configuration = MLModelConfiguration()
            let model = try VNCoreMLModel(for: SqueezeNet(configuration: configuration).model)
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self else {
                    return
                }
                self.processClassifications(for: request, error: error)
            }
            
            
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        quoteTextView.isHidden = true
        addStickerButton.isEnabled = false
        
        addCanvasForDrawing()
        drawingView.isHidden = true
    }
    
    // MARK: - Actions
    @IBAction func selectPhotoPressed(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: true)
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func addStickerDoneUnwind(_ unwindSegue: UIStoryboardSegue) {
        guard
            let sourceViewController = unwindSegue.source as? AddStickerViewController,
            let selectedEmoji = sourceViewController.selectedEmoji
        else {
            return
        }
        addStickerToCanvas(selectedEmoji, at: stickerFrame)
    }
}

// MARK: - Private methods
private extension CreateQuoteViewController {
    func addStickerToCanvas(_ sticker: String, at rect: CGRect) {
        let stickerLabel = UILabel(frame: rect)
        stickerLabel.text = sticker
        stickerLabel.font = .systemFont(ofSize: 100)
        stickerLabel.numberOfLines = 1
        stickerLabel.baselineAdjustment = .alignCenters
        stickerLabel.textAlignment = .center
        stickerLabel.adjustsFontSizeToFitWidth = true
        
        // Add sticker to the canvas
        stickerView.addSubview(stickerLabel)
    }
    
    func clearStickersFromCanvas() {
        for view in stickerView.subviews {
            view.removeFromSuperview()
        }
    }
    
    func addCanvasForDrawing() {
        drawingView = DrawingView(frame: stickerView.bounds)
        view.addSubview(drawingView)
        drawingView.delegate = self
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            drawingView.topAnchor.constraint(equalTo: stickerView.topAnchor),
            drawingView.leftAnchor.constraint(equalTo: stickerView.leftAnchor),
            drawingView.rightAnchor.constraint(equalTo: stickerView.rightAnchor),
            drawingView.bottomAnchor.constraint(equalTo: stickerView.bottomAnchor)
        ])
    }
    
    func getQuote(for keywords: [String]? = nil) -> Quote? {
        if let keywords = keywords {
            for keyword in keywords {
                for quote in quoteList {
                    if quote.keywords.contains(keyword) {
                        return quote
                    }
                }
            }
        }
        return selectRandomQuote()
    }
    
    func selectRandomQuote() -> Quote? {
        if let quote = quoteList.randomElement() {
            return quote
        }
        return nil
    }
}

// MARK: - UIImagePickerControllerDelegate
extension CreateQuoteViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        imageView.image = image
        quoteTextView.isHidden = false
        addStickerButton.isEnabled = true
        drawingView.isHidden = false
        starterLabel.isHidden = true
        clearStickersFromCanvas()
        
        classifyImage(image)
    }
}

// MARK - UIGestureRecognizerDelegate
extension CreateQuoteViewController: UIGestureRecognizerDelegate {
    @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: stickerView)
        if let view = recognizer.view {
            view.center = CGPoint(
                x:view.center.x + translation.x,
                y:view.center.y + translation.y)
        }
        recognizer.setTranslation(CGPoint.zero, in: stickerView)
        
        if recognizer.state == UIGestureRecognizer.State.ended {
            let velocity = recognizer.velocity(in: stickerView)
            let magnitude =
                sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
            let slideMultiplier = magnitude / 200
            
            let slideFactor = 0.1 * slideMultiplier
            var finalPoint = CGPoint(
                x:recognizer.view!.center.x + (velocity.x * slideFactor),
                y:recognizer.view!.center.y + (velocity.y * slideFactor))
            finalPoint.x =
                min(max(finalPoint.x, 0), stickerView.bounds.size.width)
            finalPoint.y =
                min(max(finalPoint.y, 0), stickerView.bounds.size.height)
            
            UIView.animate(
                withDuration: Double(slideFactor * 2),
                delay: 0,
                options: UIView.AnimationOptions.curveEaseOut,
                animations: {recognizer.view!.center = finalPoint },
                completion: nil)
        }
    }
    
    func classifyImage(_ image: UIImage) {
        // 1
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) else {
            return
        }
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        // 2
        DispatchQueue.global(qos: .userInitiated).async {
            let handler =
                VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            // 1
            if let classifications =
                request.results as? [VNClassificationObservation] {
                // 2
                let topClassifications = classifications.prefix(2).map {
                    (confidence: $0.confidence, identifier: $0.identifier)
                }
                print("Top classifications: \(topClassifications)")
                let topIdentifiers =
                    topClassifications.map {$0.identifier.lowercased() }
                // 3
                if let quote = self.getQuote(for: topIdentifiers) {
                    self.quoteTextView.text = quote.text
                }
            }
        }
    }
}

extension CreateQuoteViewController: DrawingViewDelegate {
    func drawingDidChange(_ drawingView: DrawingView) {
        // 1
        let drawingRect = drawingView.boundingSquare()
        let drawing = Drawing(
            drawing: drawingView.canvasView.drawing,
            rect: drawingRect)
        // 2
        let imageFeatureValue = drawing.featureValue
        // 3
        let drawingLabel =
            UpdatableModel.predictLabelFor(imageFeatureValue)
        // 4
        DispatchQueue.main.async {
            drawingView.clearCanvas()
            guard let emoji = drawingLabel else {
                return
            }
            self.addStickerToCanvas(emoji, at: drawingRect)
        }
    }
}
