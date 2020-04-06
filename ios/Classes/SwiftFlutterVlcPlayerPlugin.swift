import Flutter
import UIKit
import MobileVLCKit

public class SwiftFlutterVlcPlayerPlugin: NSObject, FlutterPlugin {
    
    var factory: VLCViewFactory
    public init(with registrar: FlutterPluginRegistrar) {
        self.factory = VLCViewFactory(withRegistrar: registrar)
        registrar.register(factory, withId: "flutter_video_plugin/getVideoView")
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.addApplicationDelegate(SwiftFlutterVlcPlayerPlugin(with: registrar))
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
    }
    
    
}


public class VLCView: NSObject, FlutterPlatformView {
    
    
   
    
    @IBOutlet var hostedView: UIView!
    var vlcMediaPlayer: VLCMediaPlayer?
    var registrar: FlutterPluginRegistrar
    var channel: FlutterMethodChannel
    var eventChannel: FlutterEventChannel
    var player: VLCMediaPlayer
    var eventChannelHandler: VLCPlayerEventStreamHandler
    var aspectSet = false
 
    
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withId id: Int64){
        self.registrar = registrar
        self.hostedView = UIView()
        self.player = VLCMediaPlayer()
        self.channel = FlutterMethodChannel(name: "flutter_video_plugin/getVideoView_\(id)", binaryMessenger: registrar.messenger())
        self.eventChannel = FlutterEventChannel(name: "flutter_video_plugin/getVideoEvents_\(id)", binaryMessenger: registrar.messenger())
        self.eventChannelHandler = VLCPlayerEventStreamHandler()
        
    
    }
    
    public func view() -> UIView {
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        
            var arguments = call.arguments as! Dictionary<String, Any>
            switch(call.method){
            case "initialize":
                
                
                let url = arguments["url"] as? String
                
                let media = VLCMedia(url: URL(string: url!)!)
                self?.player.media = media
                self?.player.position = 0.5
                self?.player.drawable = self?.hostedView
                self?.player.delegate = self?.eventChannelHandler
                
                result(nil)
                return
            case "setPlaybackState":
                let playbackState = arguments["playbackState"] as? String
                
                if (playbackState == "play") {
                    self?.player.play()
                } else if (playbackState == "pause") {
                    self?.player.pause()
                } else if (playbackState == "stop") {
                    self?.player.stop()
                }
                
                result(nil)
                return
            case "dispose":
                self?.player.stop()
                return
            case "changeURL":
                if (self?.player == nil )
                {
                    result(FlutterError(code: "VLC_NOT_INITIALIZED", message: "The player has not yet been initialized.", details: nil))
                    
                }
                self?.player.stop()
                let url = arguments["url"] as? String
                let media = VLCMedia(url: URL(string: url!)!)
                self?.player.media = media
                result(nil)
                return
                
            case "getSnapshot":
                let drawable:UIView = self?.player.drawable as! UIView
                let size = drawable.frame.size
                
                UIGraphicsBeginImageContextWithOptions(size , _: false, _: 0.0)
                
                let rec = drawable.frame
                drawable.drawHierarchy(in: rec , afterScreenUpdates: false)
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                let byteArray = (image ?? UIImage()).pngData()
                
                result([
                    "snapshot": byteArray
                ])
                return
                
            case "setPlaybackState":
                let playbackState = arguments["playbackState"] as? String
                
                if (playbackState == "play") {
                    self?.player.play()
                } else if (playbackState == "pause") {
                    self?.player.pause()
                } else if (playbackState == "stop") {
                    self?.player.stop()
                }
                result(nil)
                return
                
            case "setPlaybackSpeed":
                
                let playbackSpeed = arguments["speed"] as? NSNumber
                let rate = playbackSpeed?.floatValue ?? 0.0
                self?.player.rate = rate
                result(nil)
                return
                
            case "setTime":
                
                let time = VLCTime(number: arguments["time"] as? NSNumber)
                self?.player.time = time
                result(nil)
                return
                
            default:
                result(FlutterMethodNotImplemented)
                return
            }
        })
        
        //eventChannel.setStreamHandler(eventChannelHandler)
        return hostedView
    }
    
 
    
}

class VLCPlayerEventStreamHandler:NSObject, FlutterStreamHandler, VLCMediaPlayerDelegate {
    
    var eventSink: FlutterEventSink?
    
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    
    @objc func mediaPlayerStateChanged(_ aNotification: Notification?) {
        
        let player = aNotification?.object as? VLCMediaPlayer
        let media = player?.media
        var tracks: [Any] = media?.tracksInformation ?? [""]  //[Any]
        var track:NSDictionary
        
        var ratio = Float(0.0)
        var height = 0
        var width =  0
        var index: Int32
        index = player?.currentVideoTrackIndex as! Int32
        
        if player?.currentVideoTrackIndex != -1 {
            if let currentVideoTrackIndex = player?.currentVideoTrackIndex {
                track =  tracks[0] as! NSDictionary
                height = track["height"] as! Int
                width = track["width"] as! Int
                
                if height != nil && width != nil  {
                    ratio = Float(width / height)
                }
                
            }
            
        }
        
        switch player?.state {
        case .esAdded, .buffering, .opening:
            return
        case .playing:
            eventSink?([
                "name": "buffering",
                "value": NSNumber(value: false)
            ])
            if let value = media?.length.value {
                eventSink?([
                    "name": "playing",
                    "value": NSNumber(value: true),
                    "ratio": NSNumber(value: ratio),
                    "height": height,
                    "width": width,
                    "length": value
                ])
            }
            return
        case .ended:
            eventSink?([
                "name": "ended"
            ])
            eventSink?([
                "name": "playing",
                "value": NSNumber(value: false),
                "reason": "EndReached"
            ])
            return
        case .error:
            print("(flutter_vlc_plugin) A VLC error occurred.")
            return
        case .paused, .stopped:
            eventSink?([
                "name": "buffering",
                "value": NSNumber(value: false)
            ])
            eventSink?([
                "name": "playing",
                "value": NSNumber(value: false)
            ])
            return
        default:
            break
        }
        
    }
    
    @objc func mediaPlayerTimeChanged(_ aNotification: Notification?) {

          let player = aNotification?.object as? VLCMediaPlayer

          if let value = player?.time.value {
              eventSink?([
              "name": "timeChanged",
              "value": value,
              "speed": NSNumber(value: player?.rate ?? 1.0)
              ])
          }

          return
      }
}




public class VLCViewFactory: NSObject, FlutterPlatformViewFactory {
    
    var registrar: FlutterPluginRegistrar?
    
    public init(withRegistrar registrar: FlutterPluginRegistrar){
        super.init()
        self.registrar = registrar
    }
    
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        var dictionary =  args as! Dictionary<String, Double>
        return VLCView(withFrame: CGRect(x: 0, y: 0, width: dictionary["width"] ?? 0, height: dictionary["height"] ?? 0), withRegistrar: registrar!,withId: viewId)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec(readerWriter: FlutterStandardReaderWriter())
    }
}
