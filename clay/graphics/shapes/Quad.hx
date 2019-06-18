package clay.graphics.shapes;


import clay.math.VectorCallback;
import clay.math.Vector;
import clay.render.Vertex;
import clay.render.GeometryType;
import clay.render.RenderPath;
import clay.render.Camera;
import clay.graphics.Mesh;


class Quad extends Mesh {


	public var size  (default, null):VectorCallback;


	public function new(w:Float = 32, h:Float = 32) {

		size = new VectorCallback(w, h);
		size.listen(size_changed);

		var vertices = [
			new Vertex(new Vector(0, 0), new Vector(0, 0)),
			new Vertex(new Vector(w, 0), new Vector(1, 0)),
			new Vertex(new Vector(w, h), new Vector(1, 1)),
			new Vertex(new Vector(0, h), new Vector(0, 1))
		];

		super(vertices, null, null);
		
		sort_key.geomtype = GeometryType.quad;

	}
	
	override function render_geometry(r:RenderPath, c:Camera) {

		r.set_object_renderer(r.quad_renderer);
		r.quad_renderer.render(this);

	}

	function size_changed(v:Float) {
		
		var w:Float = size.x;
		var h:Float = size.y;

		vertices[0].pos.set(0, 0);
		vertices[1].pos.set(w, 0);
		vertices[2].pos.set(w, h);
		vertices[3].pos.set(0, h);

	}


}