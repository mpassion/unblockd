import SwiftUI

struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        if let nsImage = IconLoader.loadMenuBarIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "lock.open.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

class IconLoader {
    static func loadMenuBarIcon() -> NSImage? {
        let name = "MenuBarIcon"

        if let image = Bundle.module.image(forResource: name) {
            return image
        }

        let bundleParams = [
            ("icon@3x.png", 3.0),
            ("icon@2x.png", 2.0),
            ("icon.png", 1.0)
        ]

        for (filename, _) in bundleParams {
             let path = "Assets.xcassets/\(name).imageset/\(filename)"

             if let imagePath = Bundle.module.path(forResource: path, ofType: nil),
                let image = NSImage(contentsOfFile: imagePath) {
                 return process(image)
             }

            if let resourceURL = Bundle.module.resourceURL {
                 let directPath = resourceURL.appendingPathComponent(path)
                 if let image = NSImage(contentsOf: directPath) {
                     return process(image)
                 }
            }
        }

        return nil
    }

    private static func process(_ image: NSImage) -> NSImage {
        image.isTemplate = true
        return image
    }
}
