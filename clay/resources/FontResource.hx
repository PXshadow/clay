package clay.resources;

import clay.resources.ResourceManager;

@:access(kha.Kravur)
@:access(kha.KravurImage)
class FontResource extends Resource {

	@:noCompletion public var font:kha.Font;
	public var textures(default, null):Map<Int, Texture>;

	public function new(font:kha.Font) {
		this.font = font;
		textures = new Map();
		
		resourceType = ResourceType.FONT;
	}

	override function unload() {
		font.unload();
		for (t in textures) {
			t.unload();
		}
	}
	
	override function memoryUse() {
        return font.blob.length;
	}

	public function get(fontSize:Int):Texture {
		var t = textures.get(fontSize);

		if(t == null) {
			var k = font._get(fontSize);
			t = new Texture(k.getTexture());
			t.id = id + "_" + fontSize;
			textures.set(fontSize, t);
			Clay.resources.add(t);
		}

		return t;
	}

	public function height(fontSize:Int):Float {
		return font._get(fontSize).getHeight();
	}

	public function width(fontSize:Int, str:String):Float {
		return font._get(fontSize).stringWidth(str);
	}

	public function charWidth(fontSize:Int, charCode:Int):Float {
		return font._get(fontSize).getCharWidth(charCode);
	}

	public function charactersWidth(fontSize:Int, characters:Array<Int>, start:Int, length:Int):Float {
		return font._get(fontSize).charactersWidth(characters, start, length);
	}

}
