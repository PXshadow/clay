package clay.resources;

import clay.resources.Resource;
import clay.resources.AudioResource;
import clay.resources.BytesResource;
import clay.resources.FontResource;
import clay.resources.JsonResource;
// import clay.resources.ShaderResource;
import clay.resources.Texture;
import clay.resources.VideoResource;
import clay.resources.TextResource;
import clay.utils.Log.*;

import haxe.io.Path;

@:allow(clay.system.App)
class ResourceManager {

	static final resourcesPath:String = 'data';

	public var cache(default, null):Map<String, Resource>;
	public var stats:ResourceStats;

	var _textureExt:Array<String>;
	var _audioExt:Array<String>;
	var _fontExt:Array<String>;
	var _videoExt:Array<String>;

	function new() {
		_textureExt = kha.Assets.imageFormats;
		_audioExt = kha.Assets.soundFormats;
		_videoExt = [];
		// _videoExt = kha.Assets.videoFormats; // TODO: bug on hl
		_fontExt = kha.Assets.fontFormats;

		cache = new Map();

		stats = new ResourceStats();
	}

	function destroy() {
		unloadAll();
	}

	public function loadAll(arr:Array<String>, onComplete:()->Void, ?onProgress:(p:Float)->Void) {
		if(arr.length == 0) {
			if(onProgress != null) {
				onProgress(1);
			}
			onComplete();
			return;
		}

		var progress:Float = 0;
		var count:Int = arr.length;
		var left:Int = count;

		var i:Int = 0;

		var cb:(r:Resource)->Void = null;

		cb = function(r) {
			i++;
			left--;
			progress = 1 - left / count;

			if(onProgress != null) {
				onProgress(progress);
			}

			if(i < count) {
				load(arr[i], cb);
			} else {
				onComplete();
			}

		}

		load(arr[i], cb);
	}

	public function unloadAll() {
		for (r in cache) {
			r.unload();
		}
		cache = new Map();
	}

	public function load(id:String, ?onComplete:(r:Resource)->Void) {
		var res = cache.get(id);
		if(res != null) {
			log("resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		var ext = Path.extension(id);

		switch (ext) {
			case e if (_textureExt.indexOf(e) != -1):{
				loadTexture(id, onComplete);
			}
			case e if (_fontExt.indexOf(e) != -1):{
				loadFont(id, onComplete);
			}
			case e if (_audioExt.indexOf(e) != -1):{
				loadAudio(id, onComplete);
			}
			case e if (_videoExt.indexOf(e) != -1):{
				loadVideo(id, onComplete);
			}
			case "json":{
				loadJson(id, onComplete);
			}
			case "txt":{
				loadText(id, onComplete);
			}
			default:{
				loadBytes(id, onComplete);
			}
		}
	}

	public function loadBytes(id:String, ?onComplete:(r:BytesResource)->Void) {
		var res:BytesResource = cast cache.get(id);

		if(res != null) {
			log("bytes resource already exists: " + id);
			// res.ref++;
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("bytes / loading / " + id);

		kha.Assets.loadBlobFromPath(
			getResourcePath(id), 
			function(blob:kha.Blob){
				res = new BytesResource(blob);
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadText(id:String, ?onComplete:(r:TextResource)->Void) {
		var res:TextResource = cast cache.get(id);

		if(res != null) {
			log("text resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("text / loading / " + id);

		kha.Assets.loadBlobFromPath(
			getResourcePath(id), 
			function(blob:kha.Blob){
				res = new TextResource(blob.toString());
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadJson(id:String, ?onComplete:(r:JsonResource)->Void) {
		var res:JsonResource = cast cache.get(id);

		if(res != null) {
			log("json resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("json / loading / " + id);

		kha.Assets.loadBlobFromPath(
			getResourcePath(id), 
			function(blob:kha.Blob){
				res = new JsonResource(haxe.Json.parse(blob.toString()));
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadTexture(id:String, ?onComplete:(r:Texture)->Void) {
		var res:Texture = cast cache.get(id);

		if(res != null) {
			log("texture resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("texture / loading / " + id);

		kha.Assets.loadImageFromPath(
			getResourcePath(id), 
			false, 
			function(img:kha.Image){
				res = new Texture(img);
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadFont(id:String, ?onComplete:(r:FontResource)->Void) {
		var res:FontResource = cast cache.get(id);

		if(res != null) {
			log("font resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("font / loading / " + id);

		kha.Assets.loadFontFromPath(
			getResourcePath(id), 
			function(f:kha.Font){
				res = new FontResource(f);
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadVideo(id:String, ?onComplete:(r:VideoResource)->Void) {
		var res:VideoResource = cast cache.get(id);

		if(res != null) {
			log("video resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("video / loading / " + id);

		kha.Assets.loadVideoFromPath(
			getResourcePath(id), 
			function(v:kha.Video){
				res = new VideoResource(v);
				res.id = id;
				add(res);
				if(onComplete != null) {
					onComplete(res);
				}
			},
			onError
		);
	}

	public function loadAudio(id:String, ?onComplete:(r:AudioResource)->Void) {
		var res:AudioResource = cast cache.get(id);

		if(res != null) {
			log("audio resource already exists: " + id);
			if(onComplete != null) {
				onComplete(res);
			}
			return;
		}

		_debug("audio / loading / " + id);

		kha.Assets.loadSoundFromPath(
			getResourcePath(id), 
			function(snd:kha.Sound){
				snd.uncompress(function() {
					res = new AudioResource(snd);
					res.id = id;
					add(res);
					if(onComplete != null) {
						onComplete(res);
					}
				});
			},
			onError
		);
	}

	public function add(resource:Resource) {
		assert(!cache.exists(resource.id));

		cache.set(resource.id, resource);

		updateStats(resource, 1);
	}

	public function remove(resource:Resource):Bool {
		assert(cache.exists(resource.id));

		updateStats(resource, -1);

		return cache.remove(resource.id);
	}

	public function unload(id:String):Bool {
		var res = get(id);
		if(res != null) {
			res.unload();
			cache.remove(res.id);
			return true;
		}

		return false;
	}

	public inline function has(id:String):Bool return cache.exists(id);

	public function get(id:String):Resource return fetch(id);
	public function bytes(id:String):BytesResource return fetch(id);
	public function text(id:String):TextResource return fetch(id);
	public function json(id:String):JsonResource return fetch(id);
	public function texture(id:String):Texture return fetch(id);
	public function font(id:String):FontResource return fetch(id);
	public function video(id:String):VideoResource return fetch(id);
	public function audio(id:String):AudioResource return fetch(id);

	inline function fetch<T>(id:String):T {
		var res:T = cast cache.get(id);

		if(res == null) {
			log("failed to get resource: " + id);
		}

		return res;
	}

	inline function updateStats(_res:Resource, _offset:Int) {
		switch(_res.resourceType) {
			case ResourceType.UNKNOWN:          stats.unknown   += _offset;
			case ResourceType.BYTES:            stats.bytes     += _offset;
			case ResourceType.TEXT:             stats.texts     += _offset;
			case ResourceType.JSON:             stats.jsons     += _offset;
			case ResourceType.TEXTURE:          stats.textures  += _offset;
			case ResourceType.RENDERTEXTURE:    stats.rtt       += _offset;
			case ResourceType.FONT:             stats.fonts     += _offset;
			// case ResourceType.SHADER:           stats.shaders   += _offset;
			case ResourceType.AUDIO:            stats.audios    += _offset;
			case ResourceType.VIDEO:            stats.videos    += _offset;
			default:
		}

		stats.total += _offset;
	}

	inline function getResourcePath(path:String):String {
		return Path.join([resourcesPath, path]);
	}
	
	function onError(err:kha.AssetError) { // TODO: remove from path resourcesPath
		log("failed to load resource: " + err.url);
	}

}

class ResourceStats {

	public var total:Int = 0;
	public var fonts:Int = 0;
	public var textures:Int = 0;
	public var rtt:Int = 0;
	// public var shaders:Int = 0;
	public var texts:Int = 0;
	public var jsons:Int = 0;
	public var bytes:Int = 0;
	public var audios:Int = 0;
	public var videos:Int = 0;
	public var unknown:Int = 0;

	public function new() {} 

	function toString() {
		return
			"Resource Statistics\n" +
			"\ttotal : " + total + "\n" +
			"\ttexture : " + textures + "\n" +
			"\trender texture : " + rtt + "\n" +
			"\tfont : " + fonts + "\n" +
			// "\tshader : " + shaders + "\n" +
			"\ttext : " + texts + "\n" +
			"\tjson : " + jsons + "\n" +
			"\tbytes : " + bytes + "\n" +
			"\taudios : " + audios + "\n" +
			"\tvideos : " + audios + "\n" +
			"\tunknown : " + unknown;
	} 

	public function reset() {
		total = 0;
		fonts = 0;
		textures = 0;
		rtt = 0;
		// shaders = 0;
		texts = 0;
		jsons = 0;
		bytes = 0;
		audios = 0;
		videos = 0;
		unknown = 0;
	} 

}

enum abstract ResourceType(Int) {
	var UNKNOWN;
	var TEXT;
	var JSON;
	var BYTES;
	var TEXTURE;
	var RENDERTEXTURE;
	var FONT;
	var SHADER;
	var AUDIO;
	var VIDEO;
}