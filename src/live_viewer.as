package
{
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.AsyncErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.clearTimeout;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	import flash.media.SoundTransform;
	import flash.media.SoundChannel;
		
//	[SWF( width="640", height="480", backgroundColor="000000" )]
	public class live_viewer extends Sprite
	{
		// - video settings
		private var stage_height:int;
		private var stage_width:int;
			
		
		private const VIDEO_ASPECT_RATIO:Number = 2.0 / 3.0;
		private var video_width:int;
		private var video_height:int;
		private var video_x:int;
		private var video_y:int;
		
		public var netStreamObj:NetStream;
		public var nc:NetConnection;
		public var vid:Video;
		public var nsVol:SoundTransform = new SoundTransform(1);
		public var mychannel:SoundChannel = new SoundChannel();
		
		public var stream_name:String;
		public var stream_url:String;
		public var metaListener:Object;
				
		private var is_connected:Boolean = false;
		private var recon_timeout_id:uint = 0;
		private var explicit_close:Boolean = false;
		
		public function live_viewer()
		{
			if(ExternalInterface.available == false){
				this.logOutput("LIVE_CASTER_NOT_AVAILABLE");
				return;
			}
			
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode = StageScaleMode.NO_SCALE;			
			initExternalInterfaceCallbacks();
			
			ExternalInterface.call("broadcastLive.connectBroadcastStream");
		}
		
		//MARK: - initialize the functions accessible in javascript
		private function initExternalInterfaceCallbacks(): void {
			ExternalInterface.addCallback("live_viewer__initializeRtmp", initializeRtmp);
			ExternalInterface.addCallback("live_viewer__closeStreams", closeStreams);
			ExternalInterface.addCallback("live_viewer__reconnectRtmp", reconnectRtmp);
			ExternalInterface.addCallback("live_viewer__setVolume", setVolume);
		}
	
		private function initializeRtmp(streamUrl:String, streamName:String):void
		{
			logOutput("CONNECT_BROADCAST_STREAM");
			logOutput("-------------------------");
			logOutput("STREAM_URL: " + streamUrl);
			logOutput("STREAM_NAME: " + streamName);
			logOutput("-------------------------");
			closeStreams();
			stream_name  = streamName;
			stream_url = streamUrl;
			
			vid = new Video();
			
			
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			nc.client = { onBWDone: function():void{} };
			nc.connect(stream_url); 
		}
		
		private function reconnectRtmp(): void {
			logOutput("RECONNECTING...... ");
			initializeRtmp(stream_url, stream_name);
		}
		
		
		private function onConnectionStatus(event:NetStatusEvent):void
		{
			
			logOutput("[ STATUS ] - " + event.info.code);
			
			if (event.info.code == "NetConnection.Connect.Success")
			{
				trace("Creating NetStream");
				netStreamObj = new NetStream(nc);
				
				metaListener = new Object();
				metaListener.onMetaData = received_Meta;
				netStreamObj.client = metaListener;
				
				
				netStreamObj.play(stream_name);
				netStreamObj.soundTransform = nsVol;
				vid.attachNetStream(netStreamObj);
				addChild(vid);
			}
			if (event.info.code == "NetConnection.Connect.Failed") {
				logOutput("Connection failed.");
				logOutput("Old connection closing... (on NetConnection.Connect.Failed)");
				closeStreams();
				logOutput("Old connection closed. (on NetConnection.Connect.Failed)");
				
				// - reconnect stream	
				if (recon_timeout_id != 0) clearTimeout(recon_timeout_id);
				recon_timeout_id = setTimeout(reconnectRtmp, 500);
			}
			if (event.info.code == "NetConnection.Connect.Closed" && !explicit_close) {
				logOutput("Connection closed.");
				logOutput("Old connection closing... (on NetConnection.Connect.Closed)");
				closeStreams();
				logOutput("Old connection closed. (on NetConnection.Connect.Closed)");
				
				// - reconnect stream
				if (recon_timeout_id != 0) clearTimeout(recon_timeout_id);
				recon_timeout_id = setTimeout(reconnectRtmp, 500);
			}
		}
		
		private function closeStreams():void {
			if (nc != null) {
				explicit_close = true;
				nc.close();
				nc = null;
				explicit_close = false;
			}
		}
		
		
		public function setVolume(volume:Number):void {
			nsVol.volume = volume;
			netStreamObj.soundTransform = nsVol;
		}
		
		public function onFCSubscribe(info:Object):void
		{ trace("onFCSubscribe - succesful"); }
		
		public function onBWDone(...rest):void
		{ 
			var p_bw:Number; 
			if (rest.length > 0)
			{ p_bw = rest[0]; }
			trace("bandwidth = " + p_bw + " Kbps."); 
		}
		
		
		
		private function received_Meta (data:Object):void
		{		
			var Aspect_num:Number; //should be an "int" but that gives blank picture with sound
			Aspect_num = data.width / data.height;
			video_x = 0;
			video_y = 0;
			stage_width = this.stage.stageWidth;
			stage_height = this.stage.stageHeight;
			video_height = stage_height;
			video_width = video_height * Aspect_num;
			video_x = (stage_width - video_width) / 2;						
			vid.x = video_x;
			vid.y = video_y;
			vid.width = video_width;
			vid.height = video_height;
		}
		
		public function asyncErrorHandler(event:AsyncErrorEvent):void 
		{ 
			trace("asyncErrorHandler.." + "\r"); 
		}
				
		private function logOutput(message:String):void {
			ExternalInterface.call("console.log", message);
		}
	}
}