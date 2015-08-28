import Cocoa
import Accelerate
import CoreGraphics

func image(withImage image:NSImage, buildVersion:String, buildNumber:String, buildType:String) -> NSImage {
    //Generate blured image
    let imageScale = image.recommendedLayerContentsScale(1)
    let screenScale = NSScreen.mainScreen()!.backingScaleFactor
    let size = CGSize(width: image.size.width / screenScale * imageScale, height: image.size.height / screenScale * imageScale)
    
    let bluredImage = image.applyBlurWithRadius(size.width * 0.1, tintColor: NSColor(white: 0.11, alpha: 0.3), saturationDeltaFactor: 1.8)
    let bounds = CGRect(origin: CGPointZero, size: size)
    let overlayHeight = size.height * 0.35
    let overlayFrame = CGRect(origin: CGPoint.zero, size: CGSize(width: size.width, height: overlayHeight))
    
    let outputImage = NSImage(size: size)
    outputImage.lockFocus()
    let context = NSGraphicsContext.currentContext()!.CGContext
    
    //Draw original image
    image.drawInRect(bounds)
    
    //Draw clipped blured image
    CGContextSaveGState(context)
    CGContextClipToRect(context, overlayFrame)
    bluredImage?.drawInRect(bounds)
    CGContextRestoreGState(context)
    
    //Calculate color and fonts and padding
    let textColor = image.averageColor()
    let typeFont = NSFont.systemFontOfSize(overlayHeight * 0.8)
    let versionFont = NSFont.systemFontOfSize(overlayHeight * 0.45)
    let yTextPadding = overlayHeight * 0.07
    let xTextPadding = size.width * 0.05
    
    //Draw buildType
    let buildTypeFrame = CGRect(x:xTextPadding , y: 0,
        width: overlayFrame.size.width * 0.4 - xTextPadding, height: overlayFrame.height + yTextPadding)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = NSTextAlignment.Center
    let buildTypeTextAttributes = [ NSFontAttributeName: typeFont, NSForegroundColorAttributeName: textColor, NSParagraphStyleAttributeName: paragraphStyle]
    let nsBuildType = NSString(string: buildType)
    nsBuildType.drawInRect(buildTypeFrame, withAttributes: buildTypeTextAttributes)
    
    //Draw buildVersion
    let buildVersionTextAttributes = [ NSFontAttributeName: versionFont, NSForegroundColorAttributeName: textColor]
    let nsBuildVersion = NSString(string: buildVersion)
    let buildVersionFrame = CGRect(x: buildTypeFrame.maxX, y: overlayHeight * 0.5 + yTextPadding, width: overlayFrame.width - buildTypeFrame.maxX, height: overlayHeight * 0.5)
    nsBuildVersion.drawInRect(buildVersionFrame, withAttributes: buildVersionTextAttributes)
    
    //Draw buildNumber
    let nsBuildNumber = NSString(string: buildNumber)
    let buildNumberFrame = CGRect(origin: CGPoint(x: buildVersionFrame.origin.x, y: yTextPadding * 1.25), size: buildVersionFrame.size)
    nsBuildNumber.drawInRect(buildNumberFrame, withAttributes: buildVersionTextAttributes)
    
    outputImage.unlockFocus()
    return outputImage
}

public extension String {
    public func lastPathComponent() -> String {
        return self.componentsSeparatedByString("/").last!
    }
}


public extension NSImage {
    public func saveAsPNGatPath(path:String, atomically: Bool = true) -> Bool {
        let data = self.TIFFRepresentationUsingCompression(NSTIFFCompression.None, factor: 1.0)!
        let bitmap = NSBitmapImageRep(data: data)!
        if let imagePGNData: NSData = bitmap.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [NSImageCompressionFactor: 1.0]) {
            return imagePGNData.writeToFile(NSString(string: path).stringByStandardizingPath, atomically: atomically)
        } else {
            return false
        }
    }
}

public extension NSImage {
    public func averageColor() -> NSColor {
        let rgba = UnsafeMutablePointer<CUnsignedChar>.alloc(4)
        let colorSpace: CGColorSpaceRef = CGColorSpaceCreateDeviceRGB()!
        let info: UInt32 = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue).rawValue
        let context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, info)
        CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), self.CGImageForProposedRect(nil, context: nil, hints: nil)!)
        if rgba[3] > 0 {
            let alpha: CGFloat = CGFloat(rgba[3]) / 255.0
            let multiplier: CGFloat = alpha / 255.0
            return NSColor(red: CGFloat(rgba[0]) * multiplier, green: CGFloat(rgba[1]) * multiplier, blue: CGFloat(rgba[2]) * multiplier, alpha: alpha)
        } else {
            return NSColor(red: CGFloat(rgba[0]) / 255.0, green: CGFloat(rgba[1]) / 255.0, blue: CGFloat(rgba[2]) / 255.0, alpha: CGFloat(rgba[3]) / 255.0)
        }
    }
}

public extension NSImage {
    public func applyLightEffect() -> NSImage? {
        return applyBlurWithRadius(30, tintColor: NSColor(white: 1.0, alpha: 0.3), saturationDeltaFactor: 1.8)
    }
    
    public func applyExtraLightEffect() -> NSImage? {
        return applyBlurWithRadius(20, tintColor: NSColor(white: 0.97, alpha: 0.82), saturationDeltaFactor: 1.8)
    }
    
    public func applyDarkEffect() -> NSImage? {
        return applyBlurWithRadius(20, tintColor: NSColor(white: 0.11, alpha: 0.73), saturationDeltaFactor: 1.8)
    }
    
    public func applyTintEffectWithColor(tintColor: NSColor) -> NSImage? {
        let effectColorAlpha: CGFloat = 0.6
        var effectColor = tintColor
        let componentCount = CGColorGetNumberOfComponents(tintColor.CGColor)
        
        if componentCount == 2 {
            var b: CGFloat = 0
            tintColor.getWhite(&b, alpha: nil)
            effectColor = NSColor(white: b, alpha: effectColorAlpha)
        } else {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            tintColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
            effectColor = NSColor(red: red, green: green, blue: blue, alpha: effectColorAlpha)
        }
        
        return applyBlurWithRadius(10, tintColor: effectColor, saturationDeltaFactor: -1.0, maskImage: nil)
    }
    
    public func applyBlurWithRadius(blurRadius: CGFloat, tintColor: NSColor?, saturationDeltaFactor: CGFloat, maskImage: NSImage? = nil) -> NSImage? {
        // Check pre-conditions.
        if (self.size.width < 1 || self.size.height < 1) {
            print("*** error: invalid size: \(self.size.width) x \(self.size.height). Both dimensions must be >= 1: \(self)")
            return nil
        }
        if self.CGImageForProposedRect(nil, context: nil, hints: nil) == nil {
            print("*** error: image must be backed by a CGImage: \(self)")
            return nil
        }
        if maskImage != nil && maskImage!.CGImageForProposedRect(nil, context: nil, hints: nil) == nil {
            print("*** error: maskImage must be backed by a CGImage: \(maskImage)")
            return nil
        }
        
        let imageScale = self.recommendedLayerContentsScale(1)
        let screenScale = NSScreen.mainScreen()!.backingScaleFactor
        let size = CGSize(width: self.size.width / screenScale * imageScale, height: self.size.height / screenScale * imageScale)
        
        let __FLT_EPSILON__ = CGFloat(FLT_EPSILON)
        //let screenScale = NSScreen.mainScreen()?.backingScaleFactor
        let imageRect = CGRect(origin: CGPointZero, size: size)
        var effectImage = self
        
        let hasBlur = blurRadius > __FLT_EPSILON__
        let hasSaturationChange = fabs(saturationDeltaFactor - 1.0) > __FLT_EPSILON__
        
        if hasBlur || hasSaturationChange {
            func createEffectBuffer(context: CGContext) -> vImage_Buffer {
                let data = CGBitmapContextGetData(context)
                let width = vImagePixelCount(CGBitmapContextGetWidth(context))
                let height = vImagePixelCount(CGBitmapContextGetHeight(context))
                let rowBytes = CGBitmapContextGetBytesPerRow(context)
                
                return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
            }
            
            let image = NSImage(size: size)
            image.lockFocus()
            let effectInContext = NSGraphicsContext.currentContext()!.CGContext
            
            CGContextScaleCTM(effectInContext, 1.0, -1.0)
            CGContextTranslateCTM(effectInContext, 0, -size.height)
            CGContextDrawImage(effectInContext, imageRect, self.CGImageForProposedRect(nil, context: nil, hints: nil))
            
            var effectInBuffer = createEffectBuffer(effectInContext)
            
            let image2 = NSImage(size: size)
            image2.lockFocus()
            let effectOutContext = NSGraphicsContext.currentContext()!.CGContext
            var effectOutBuffer = createEffectBuffer(effectOutContext)
            
            
            if hasBlur {
                // A description of how to compute the box kernel width from the Gaussian
                // radius (aka standard deviation) appears in the SVG spec:
                // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
                //
                // For larger values of 's' (s >= 2.0), an approximation can be used: Three
                // successive box-blurs build a piece-wise quadratic convolution kernel, which
                // approximates the Gaussian kernel to within roughly 3%.
                //
                // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
                //
                // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
                //
                
                let inputRadius = blurRadius
                var radius = UInt32(floor(inputRadius * 3.0 * CGFloat(sqrt(2 * M_PI)) / 4 + 0.5))
                if radius % 2 != 1 {
                    radius += 1 // force radius to be odd so that the three box-blur methodology works.
                }
                
                let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
                
                vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            }
            
            var effectImageBuffersAreSwapped = false
            
            if hasSaturationChange {
                let s: CGFloat = saturationDeltaFactor
                let floatingPointSaturationMatrix: [CGFloat] = [
                    0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                    0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                    0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                    0,                    0,                    0,  1
                ]
                
                let divisor: CGFloat = 256
                let matrixSize = floatingPointSaturationMatrix.count
                var saturationMatrix = [Int16](count: matrixSize, repeatedValue: 0)
                
                for var i: Int = 0; i < matrixSize; ++i {
                    saturationMatrix[i] = Int16(round(floatingPointSaturationMatrix[i] * divisor))
                }
                
                if hasBlur {
                    vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                    effectImageBuffersAreSwapped = true
                } else {
                    vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                }
            }
            
            if !effectImageBuffersAreSwapped {
                effectImage = image2
            }
            image2.unlockFocus()
            
            
            if effectImageBuffersAreSwapped {
                effectImage = image
            }
            image.unlockFocus()
        }
        
        // Set up output context.
        let outputImage = NSImage(size: size)
        outputImage.lockFocus()
        let outputContext = NSGraphicsContext.currentContext()!.CGContext
        CGContextScaleCTM(outputContext, 1.0, -1.0)
        CGContextTranslateCTM(outputContext, 0, -size.height)
        
        // Draw base image.
        CGContextDrawImage(outputContext, imageRect, self.CGImageForProposedRect(nil, context: nil, hints: nil))
        
        // Draw effect image.
        if hasBlur {
            CGContextSaveGState(outputContext)
            if let image = maskImage {
                CGContextClipToMask(outputContext, imageRect, image.CGImageForProposedRect(nil, context: nil, hints: nil));
            }
            CGContextDrawImage(outputContext, imageRect, effectImage.CGImageForProposedRect(nil, context: nil, hints: nil))
            CGContextRestoreGState(outputContext)
        }
        
        // Add in color tint.
        if let color = tintColor {
            CGContextSaveGState(outputContext)
            CGContextSetFillColorWithColor(outputContext, color.CGColor)
            CGContextFillRect(outputContext, imageRect)
            CGContextRestoreGState(outputContext)
        }
        
        // Output image is ready.
        outputImage.unlockFocus()
        return outputImage
    }
}


if Process.arguments.count < 5 {
    print("You need to porvide follwing arguments in order :\n" +
        "1. Relative path for main AppIcon folder\n" +
        "2. Relative path for main Output Icon folder\n" +
        "3. Build version string\n" +
        "4. Build number string\n" +
        "5. Build type string (max 2 characters)")
    exit(1)
}

let originIconPath = NSString(string:Process.arguments[1]).stringByStandardizingPath
let outputIconPath = NSString(string:Process.arguments[2]).stringByStandardizingPath
let buildVersion = Process.arguments[3]
let buildNumber = Process.arguments[4]
let outputBuildType = Process.arguments.count < 6 ? "β" : Process.arguments[5]

let fileManager = NSFileManager()
let enumerator = fileManager.enumeratorAtPath(originIconPath)
while let currentPath = enumerator?.nextObject() as? String {
    if currentPath.rangeOfString(".png") != nil {
        if let originImage = NSImage(contentsOfFile: originIconPath + "/" + currentPath) {
            let currentOutputPath = outputIconPath + "/" + currentPath.lastPathComponent()
            let outputImage = image(withImage: originImage, buildVersion: buildVersion, buildNumber: buildNumber, buildType: outputBuildType)
            outputImage.saveAsPNGatPath(currentOutputPath)
        }
        
    }
}

