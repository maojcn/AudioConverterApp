import SwiftUI

struct ContentView: View {
    
    @State var inputFiles: [URL] = []
    @State var message: String?
    @State var showPopup = false
    @State var loading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Spacer()
                Image("Icon").resizable().frame(width: 32, height: 32)
                Text("Audio Converter").font(.system(size: 28))
                Spacer()
            }
            
            HStack() {
                if inputFiles.count > 0 {
                    List() {
                        ForEach(self.inputFiles, id: \.self) {url in
                            Text("\(url.lastPathComponent)")
                        }
                    }
                    .padding(6)
                } else {
                    Text("Drag and drop your audio file here")
                        .font(.system(size: 24))
                        .foregroundColor(Color.gray)
                }
            }
            .frame(width: 380, height: 300)
            .background() {
                ZStack() {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 380, height: 300).zIndex(-1)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, dash: [10]))
                        .frame(width: 380, height: 300)
                }
                
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                self.inputFiles = self.performDropAudio(providers: providers)
                return true
            }

            HStack() {
                if let message = self.message {
                    Text("\(message)")
                        .foregroundColor(Color.red)
                }
                Spacer()
                Button(action: {
                    if self.loading {
                        self.loading = false
                        self.message = "Aborted"
                        return
                    }
                    guard self.inputFiles.count > 0 else {
                        self.message = "Add the input file"
                        return
                    }

                    self.convert()
                    
                }) {
                    if self.loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.6)
                        Text("Stop")
                    } else {
                        Text("Start")
                    }
                }
                .foregroundColor(.white)
                .frame(width: 100, height: 40)
                .buttonStyle(PlainButtonStyle())
                .background(RoundedRectangle(cornerRadius: 8).fill(self.loading ? .red : .blue))
                .padding()
            }
        }
        .padding(30)
        .frame(width: 440)
    }
    
    func performDropAudio(providers: [NSItemProvider]) -> [URL] {
        var fileURLs: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            print("url loaded")
            group.enter()
            let _ = provider.loadObject(ofClass: URL.self) { (url, err) in
                if let url = url {
                    print("url: \(url)")
                    if url.isFileURL && url.pathExtension == "m4a" {
                        fileURLs.append(url)
                    }
                }
                group.leave()
            }
        }
        group.wait()
        print("\(fileURLs)");
        return fileURLs
    }
    
    func shell(_ launchPath: String, _ arguments: [String]) -> String?
    {
        print("\(launchPath) \(arguments.joined(separator: " "))")
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)
        return output
    }
    
    func convert() {
        self.loading = true
        let totalCount = self.inputFiles.count
        var finishedCount = 0;
        self.message = "Converting \(finishedCount)/\(totalCount) ..."
        DispatchQueue.global(qos: .background).async {
            let ffmpegPath = Bundle.main.url(forResource: "ffmpeg", withExtension: "")!.path
            let downloadFolderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            
            self.inputFiles.forEach { url in
                if !self.loading {
                    return
                }
                var outputFile = url.lastPathComponent
                let index = outputFile.index(outputFile.endIndex, offsetBy: -3)
                outputFile = outputFile[..<index] + "wav"
                let outputPath = downloadFolderURL.appendingPathComponent(outputFile).path
                
                shell(ffmpegPath, ["-y", "-i", url.path, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", outputPath])
                
                if !self.loading {
                    return
                }
                finishedCount += 1
                DispatchQueue.main.async {
                    self.message = "Converting \(finishedCount)/\(totalCount) ..."
                }
                
            }
            if !self.loading {
                return
            }
            DispatchQueue.main.async {
                self.loading = false
                self.message = "Done"
            }
        }
    }
}

#Preview {
    ContentView()
}
