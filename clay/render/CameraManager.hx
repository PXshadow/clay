package clay.render;

import kha.graphics4.Graphics;

import clay.math.Rectangle;
import clay.render.Camera;
import clay.events.Signal;
import clay.utils.Log.*;

@:access(clay.render.Camera)
class CameraManager {

	public var onCameraCreate(default, null):Signal<Camera->Void>;
	public var onCameraDestroy(default, null):Signal<Camera->Void>;

	public var length(default, null):Int;

	@:noCompletion public var activeCameras:Array<Camera>;
	@:noCompletion public var cameras:Map<String, Camera>;

	public function new() {
		activeCameras = [];
		cameras = new Map();
		length = 0;

		onCameraCreate = new Signal();
		onCameraDestroy = new Signal();
	}

	public function create(name:String, ?viewport:Rectangle, priority:Int = 0, enabled:Bool = true):Camera {
		var camera = new Camera(this, name, viewport, priority);

		handleDuplicateWarning(name);
		cameras.set(name, camera);
		length++;

		if(enabled) {
			enable(camera);
		}

		onCameraCreate.emit(camera);

		return camera;
	}

	public function destroy(camera:Camera) {
		if(cameras.exists(camera.name)) {
			cameras.remove(camera.name);
			length--;
			disable(camera);
		} else {
			log('can`t remove camera: "${camera.name}" , already removed?');
		}

		onCameraDestroy.emit(camera);

		camera.destroy();
	}

	public inline function get(name:String):Camera {
		return cameras.get(name);
	}

	public function enable(camera:Camera) {
		if(camera._active) {
			return;
		}
		
		var added:Bool = false;
		var c:Camera = null;
		for (i in 0...activeCameras.length) {
			c = activeCameras[i];
			if (camera.priority < c.priority) {
				activeCameras.insert(i, camera);
				added = true;
				break;
			}
		}

		camera._active = true;

		if(!added) {
			activeCameras.push(camera);
		}
	}

	public function disable(camera:Camera) {
		if(!camera._active) {
			return;
		}

		activeCameras.remove(camera);
		camera._active = false;
	}

	public function clear() {
		for (c in cameras) {
			destroy(c);
		}
		length = 0;
	}

	function handleDuplicateWarning(name:String) {
		var c:Camera = cameras.get(name);
		if(c != null) {
			log('adding a second camera named: "${name}"!
				This will replace the existing one, possibly leaving the previous one in limbo.');
			cameras.remove(name);
			disable(c);
		}
	}

	@:noCompletion public inline function iterator():Iterator<Camera> { // TODO: remove
		return activeCameras.iterator();
	}

}