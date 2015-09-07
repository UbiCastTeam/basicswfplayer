﻿package basicplayer {
	import flash.display.Sprite;
	import flash.media.SoundTransform;
	import flash.media.Video;

	import org.mangui.hls.HLS;
	import org.mangui.hls.HLSSettings;
	import org.mangui.hls.event.HLSEvent;
	import org.mangui.hls.constant.HLSPlayStates;
	import org.mangui.hls.utils.Log;

	import basicplayer.PlayerClass;

	public class PlayerHLS extends PlayerClass {
		private var _playqueued:Boolean = false;
		private var _hls:HLS;
		private var _url:String;
		private var _hlsState:String = HLSPlayStates.IDLE;

		// event values
		private var _isManifestLoaded:Boolean = false;
		private var _isPaused:Boolean = true;
		private var _isEnded:Boolean = false;

		private var _bufferedTime:Number = 0;
		private var _bufferEmpty:Boolean = false;
		private var _bufferingChanged:Boolean = false;
		private var _seekOffset:Number = 0;

		public function PlayerHLS(element:BasicPlayer, autoplay:Boolean, preload:String, volume:Number, muted:Boolean, timerRate:Number) {
			_element = element;
			_autoplay = autoplay;
			_preload = preload;
			_volume = volume;
			_muted = muted;
			_timerRate = timerRate;

			_video = new Video();
			//HLSSettings.logDebug = true;
			_hls = new HLS();
			_hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE,_completeHandler);
			_hls.addEventListener(HLSEvent.ERROR,_errorHandler);
			_hls.addEventListener(HLSEvent.MANIFEST_LOADED,_manifestHandler);
			_hls.addEventListener(HLSEvent.MEDIA_TIME,_mediaTimeHandler);
			_hls.addEventListener(HLSEvent.PLAYBACK_STATE,_stateHandler);
			_hls.stream.soundTransform = new SoundTransform(_volume);
			_video.attachNetStream(_hls.stream);
		}

		private function _completeHandler(event:HLSEvent):void {
			_isEnded = true;
			_isPaused = true;
			_element.sendEvent("paused", null);
		}

		private function _errorHandler(event:HLSEvent):void {
			Logger.error(event.toString());
		}

		private function _manifestHandler(event:HLSEvent):void {
			var vWidth:Number = event.levels[0].width;
			var vHeight:Number = event.levels[0].height;
			_isManifestLoaded = true;
			_hls.stage = _video.stage;
			updateDuration(event.levels[0].duration);
			// Set ratio
			if (!isNaN(vWidth) && !isNaN(vHeight) && vWidth > 0 && vHeight > 0)
				_element.setVideoRatio(vWidth / vHeight);
			else
				_element.setVideoRatio(0);
			if(_autoplay || _playqueued) {
				_playqueued = false;
				_hls.stream.play();
			}
		}

		private function _mediaTimeHandler(event:HLSEvent):void {
			_bufferedTime = event.mediatime.buffer + event.mediatime.position;
			updateTime(event.mediatime.position);
			updateDuration(event.mediatime.duration);
			updateBuffer(0, _currentTime + _bufferedTime);
		}

		private function _stateHandler(event:HLSEvent):void {
			_hlsState = event.state;
			//Log.txt("state:"+ _hlsState);
			switch(event.state) {
				case HLSPlayStates.IDLE:
					break;
				case HLSPlayStates.PAUSED_BUFFERING:
				case HLSPlayStates.PLAYING_BUFFERING:
					_isPaused = true;
					_element.sendEvent("buffering", null);
					break;
				case HLSPlayStates.PLAYING:
					_isPaused = false;
					_isEnded = false;
					_video.visible = true;
					_element.sendEvent("playing", null);
					break;
				case HLSPlayStates.PAUSED:
					_isPaused = true;
					_isEnded = false;
					_element.sendEvent("paused", null);
					break;
			}
		}

		// Overriden functions
		// -------------------------------------------------------------------
		public override function setSrc(url:String):void{
			//Log.txt("HLSMediaElement:setSrc:"+url);
			stopMedia();
			_url = url;
			_hls.load(_url);
		}

		public override function loadMedia():void{
			//Log.txt("HLSMediaElement:load");		
			if(_url) {
				_element.sendEvent("buffering", null);
				_hls.load(_url);
			}
		}

		public override function playMedia():void {
			//Log.txt("HLSMediaElement:play");
			if(!_isManifestLoaded) {
				_playqueued = true;
				return;
			}
			if (_hlsState == HLSPlayStates.PAUSED || _hlsState == HLSPlayStates.PAUSED_BUFFERING) {
				_hls.stream.resume();
			} else {
				_hls.stream.play();
			}
		}

		public override function pauseMedia():void {
			if(!_isManifestLoaded)
				return;
			//Log.txt("HLSMediaElement:pause");
			_hls.stream.pause();
		}

		public override function stopMedia():void{
			_hls.stream.seek(0);
			_hls.stream.pause();
			updateTime(0);
			_element.sendEvent("stopped", null);
		}

		public override function seek(pos:Number):void{
			if(!_isManifestLoaded)
				return;
			_hls.stream.seek(pos);
		}

		public override function setVolume(vol:Number):void{
			_volume = vol;
			_muted = (_volume == 0);
			_hls.stream.soundTransform = new SoundTransform(vol);
		}

		public override function setMuted(muted:Boolean):void {
			// ignore if no change
			if (muted === _muted)
				return;

			_muted = muted;

			if (muted) {
				_hls.stream.soundTransform = new SoundTransform(0);
			} else {
				setVolume(_volume);
			}
		}
	}
}