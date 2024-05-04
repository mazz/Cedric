//
//  TestResources.swift
//  CedricTests
//
//  Created by Szymon Mrozek on 07.05.2018.
//  Copyright © 2018 AppUnite. All rights reserved.
//

import Foundation
import UIKit
@testable import Cedric

class TestResources {
    
    static let standardResources: [DownloadResource] = [
        DownloadResource(id: "1", source: URL(string: "https://download.samplelib.com/png/sample-boat-400x300.png")!, destinationName: "sample-boat-400x300.png"),
        DownloadResource(id: "2", source: URL(string: "https://download.samplelib.com/png/sample-hut-400x300.png")!, destinationName: "sample-hut-400x300.png"),
        DownloadResource(id: "3", source: URL(string: "https://download.samplelib.com/png/sample-bumblebee-400x300.png")!, destinationName: "sample-bumblebee-400x300.png"),
        DownloadResource(id: "4", source: URL(string: "https://download.samplelib.com/png/sample-clouds2-400x300.png")!, destinationName: "sample-clouds2-400x300.png"),
        DownloadResource(id: "5", source: URL(string: "https://download.samplelib.com/png/sample-red-400x300.png")!, destinationName: "sample-red-400x300.png"),
        DownloadResource(id: "6", source: URL(string: "https://download.samplelib.com/png/sample-green-400x300.png")!, destinationName: "sample-green-400x300.png")
    ]
}

extension DownloadResource {
    var localImageRepresentation: UIImage {
        let bundle = Bundle(for: TestResources.self)
        guard let path = bundle.path(forResource: self.destinationName.replacingOccurrences(of: ".png", with: "") , ofType: "png") else {
            fatalError("Could not find image")
        }
        
        let url = URL(fileURLWithPath: path)
        return UIImage(contentsOfFile: url.path)!
    }
}
