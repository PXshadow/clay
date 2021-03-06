package clay.render;



import kha.graphics4.ConstantLocation;
import kha.graphics4.TextureUnit;
import kha.graphics4.IndexBuffer;
import kha.graphics4.Usage;
import kha.graphics4.TextureFormat;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.Graphics;
import kha.arrays.Float32Array;
import kha.arrays.Uint32Array;
import kha.math.FastMatrix3;
import kha.Image;

import clay.math.Vector;
import clay.utils.Color;
import clay.render.Camera;
import clay.render.RenderStats;
import clay.resources.Texture;
import clay.render.Shader;
import clay.render.types.BlendFactor;
import clay.render.types.BlendOperation;
import clay.render.TextureParameters;
import clay.render.Blending;
import clay.math.Matrix;
import clay.math.Rectangle;
import clay.utils.Mathf;
import clay.utils.ArrayTools;
import clay.utils.Log.*;
import clay.utils.BlendMode;
import clay.utils.DynamicPool;
import clay.utils.PowerOfTwo;

using clay.render.utils.FastMatrix3Extender;

@:allow(clay.render.Renderer)
class RenderContext {

	public var verticesMax(default, null):Int = 0;
	public var indicesMax(default, null):Int = 0;
	public var currentState(default, null):RenderState;

	#if !no_debug_console
	public var stats(default, null):RenderStats;
	#end

	public var states:Array<RenderState>;
	var statesPool:DynamicPool<RenderState>;

	var _renderer:Renderer;

	var _vertsDraw:Int = 0;
	var _indicesDraw:Int = 0;
	var _vertexIdx:Int = 0;

	var _textureBlank:Texture;

	var _vertices:Float32Array;
	var _indices:Uint32Array;

	var _viewportDefault:Rectangle;
	var _blendingDefault:Blending;
	var _textureParametersDefault:TextureParameters;
	var _colorDefault:Color;

	// for blit
	var _vertexBufferQuad:VertexBuffer;
	var _indexBufferQuad:IndexBuffer;

	var _rectTmp:Rectangle;
	var _matrixTmp:Matrix;
	var _fastMatrixTmp:FastMatrix3;

	var _vertexBuffers:Array<VertexBuffer>;
	var _indexBuffers:Array<IndexBuffer>;

	var _inGeometryMode:Bool = false;
	var _vertPos:Int = 0;

	public function new(renderer:Renderer, batchSize:Int) {
		_renderer = renderer;

		verticesMax = batchSize;
		indicesMax = Std.int(verticesMax / 4) * 6; // adjusted for quads

		_vertices = new Float32Array(verticesMax * 8);
		_indices = new Uint32Array(indicesMax);
		initQuadBuffers();

		_viewportDefault = new Rectangle(0, 0, Clay.screen.width, Clay.screen.height); // TODO: window size can be changed
		_textureParametersDefault = new TextureParameters();
		_blendingDefault = new Blending();
		_blendingDefault.mode = BlendMode.NORMAL;
		_colorDefault = new Color(1,1,1,1);

		_rectTmp = new Rectangle(0, 0, Clay.screen.width, Clay.screen.height);
		_matrixTmp = new Matrix();
		_fastMatrixTmp = FastMatrix3.identity();

		_textureBlank = Texture.create(1, 1, TextureFormat.RGBA32, Usage.StaticUsage);
		var pixels = _textureBlank.lock();
		pixels.setInt32(0, 0xffffffff);
		_textureBlank.unlock();

		states = [];

		_vertexBuffers = [];
		_indexBuffers = [];

		statesPool = new DynamicPool<RenderState>(16, 
			function() {
				return new RenderState();
			}
		);
	}

	function initQuadBuffers() {
		var shader = _renderer.shaders.get('textured');
		_vertexBufferQuad = new VertexBuffer(
			4, 
			shader.pipeline.inputLayout[0], 
			Usage.StaticUsage
		);

		_indexBufferQuad = new IndexBuffer(
			6, 
			Usage.StaticUsage
		);

		var vertices = _vertexBufferQuad.lock();
		// add colors
		var vertsBufLength = 4 * 8;
		var index:Int = 0;
		while(index < vertsBufLength) {
			vertices.set(index + 2, 1);
			vertices.set(index + 3, 1);
			vertices.set(index + 4, 1);
			vertices.set(index + 5, 1);
			index += 8;
		}

		// texture coords
		index = 0;
		vertices.set(index + 6, 0);
		vertices.set(index + 7, 0);

		index += 8;
		vertices.set(index + 6, 1);
		vertices.set(index + 7, 0);

		index += 8;
		vertices.set(index + 6, 1);
		vertices.set(index + 7, 1);

		index += 8;
		vertices.set(index + 6, 0);
		vertices.set(index + 7, 1);

		_vertexBufferQuad.unlock();

		var indices = _indexBufferQuad.lock();
		indices[0] = 0;
		indices[1] = 1;
		indices[2] = 2;
		indices[3] = 0;
		indices[4] = 2;
		indices[5] = 3;
		_indexBufferQuad.unlock();
	}

	public function begin(renderTexture:Texture, ?clearColor:Color) {
		assert(renderTexture.isRenderTarget, 'RenderContext: begin with non renderTarget texture');

		if(currentState != null) {
			flush();
			endInternal(currentState);
		}

		pushState(renderTexture);
		initState();

		if(clearColor != null) {
			currentState.clearColor = clearColor.toInt();
		}

		beginInternal(currentState);
	}

	public function end() {
		assert(currentState != null, 'RenderContext: no active target, begin before you end');

		flush();
		endInternal(currentState);
		popState();

		#if !no_debug_console
		stats = null;
		#end

		if(currentState != null) {
			beginInternal(currentState);
		}
	}

	public inline function setStats(stats:RenderStats) {
		#if !no_debug_console
		this.stats = stats;
		#end
	}

	public function setViewport(rect:Rectangle) {
		if(currentState.viewport != rect) {
			flush();
			currentState.viewport = rect;
		}
	}

	public function setProjection(?matrix:Matrix) {
		flush();
		if(matrix != null) {
			currentState.projectionMatrix.fromMatrix(matrix);
		} else {
			setOrtoFastMatrix3(currentState.projectionMatrix, Clay.screen.width, Clay.screen.height);
		}
	}

	public function setClipBounds(rect:Rectangle) {
		if(currentState.clipRect == null && currentState.clipBounds != rect) {
			flush();
		}
		currentState.clipBounds = rect;
	}

	public function clip(rect:Rectangle) {
		if(currentState.clipRect != rect) {
			flush();
		}
		currentState.clipRect = rect;
	}

	public function setShader(shader:Shader) {
		if(currentState.shader != shader) {
			flush();
			currentState.shader = shader;
		}
	}

	public function setTexture(texture:Texture) {
		if(currentState.texture != texture) {
			flush();
			currentState.texture = texture;
		}
	}

	public function setTextureParameters(texParam:TextureParameters) {
		if(!currentState.textureParameters.equals(texParam)) {
			flush();
			currentState.textureParameters = texParam;
		}
	}

	public function setBlending(blending:Blending) {
		if(!currentState.blending.equals(blending)) {
			flush();
			currentState.blending = blending;
		}
	}

	public function setColor(color:Color) {
		currentState.color = color;
	}

	public function canBatch(vertsCount:Int, indicesCount:Int):Bool {
		return vertsCount < verticesMax && indicesCount < indicesMax;
	}

	public function ensure(vertsCount:Int, indicesCount:Int) { // TODO: beginGeometry
		if(_vertsDraw + vertsCount >= verticesMax || _indicesDraw + indicesCount >= indicesMax) {
			flush();
		}
	}

	public function beginGeometry() {
		assert(!_inGeometryMode, 'RenderContext: beginGeometry already started');
		_inGeometryMode = true;
		_vertPos = _vertsDraw;
	}

	public inline function addIndex(i:Int) {
		_indices[_indicesDraw++] = _vertPos + i;

		#if !no_debug_console
		if(stats != null) {
			stats.indices++;
		}
		#end
	}

	public inline function addVertex(x:Float, y:Float, uvx:Float, uvy:Float) {
		var c = currentState.color;

		_vertices.set(_vertexIdx++, x);
		_vertices.set(_vertexIdx++, y);

		_vertices.set(_vertexIdx++, c.r);
		_vertices.set(_vertexIdx++, c.g);
		_vertices.set(_vertexIdx++, c.b);
		_vertices.set(_vertexIdx++, c.a);

		_vertices.set(_vertexIdx++, uvx);
		_vertices.set(_vertexIdx++, uvy);

		_vertsDraw++;

		#if !no_debug_console
		if(stats != null) {
			stats.vertices++;
		}
		#end
	}

	public function endGeometry() {
		assert(_inGeometryMode, 'RenderContext: beginGeometry is not started');
		_inGeometryMode = false;
		#if !no_debug_console
		if(stats != null) {
			stats.geometry++;
		}
		#end
	}
	
	public function drawFromBuffers(vertexbuffer:VertexBuffer, indexbuffer:IndexBuffer, count:Int = 0) {
		flush();

		if(count <= 0) {
			count = indexbuffer.count();
		}

		#if !no_debug_console
		if(stats != null) {
			stats.vertices += Math.floor(vertexbuffer.count() / 8);
			stats.indices += count;
			stats.geometry++;
		}
		#end
		
		draw(vertexbuffer, indexbuffer, count);
	}

	public function flush() {
		if(_vertsDraw == 0) {
			_verboser('nothing to draw, vertices == 0');
			return;
		}

		var vbo = getVertexBuffer(_vertsDraw);
		var ibo = getIndexBuffer(_indicesDraw);
		uploadBuffers(vbo, ibo);
		
		draw(vbo, ibo, _indicesDraw);

		_vertexIdx = 0;
		_vertsDraw = 0;
		_indicesDraw = 0;
	}

	public function renderToTexture(target:Texture, width:Int, height:Int, callBack:(ctx:RenderContext)->Void) {
		_rectTmp.set(0, 0, width, height);
		var matrix = setOrtoMatrix(_matrixTmp, width, height);
		begin(target);
		setViewport(_rectTmp);
		setClipBounds(_rectTmp);
		setProjection(matrix);
		callBack(this);
		end();
	}

	public function blit(source:Texture, target:Texture, shader:Shader, ?scale:Vector, ?offset:Vector) {
		var sx = 1.0;
		var sy = 1.0;
		var x = 0.0;
		var y = 0.0;

		if(scale != null) {
			sx = scale.x;
			sy = scale.y;
		}

		if(offset != null) {
			x = offset.x;
			y = offset.y;
		}

		var vertices = _vertexBufferQuad.lock();
		setQuadVerticesToBuffer(vertices, x, y, source.width * sx, source.height * sy);
		_vertexBufferQuad.unlock();

		var g = target.image.g4;
		var projectionMatrix = setOrtoFastMatrix3(_fastMatrixTmp, target.width, target.height);

		g.begin();
		g.clear(kha.Color.Transparent);

		drawInternal(
			g,
			projectionMatrix,
			_vertexBufferQuad,
			_indexBufferQuad,
			shader,
			source,
			_textureParametersDefault,
			_blendingDefault,
			null,
			6
		);

		g.end();
	}

	@:allow(clay.render.Renderer)
	function drawToCanvas(source:Texture, target:kha.Canvas, shader:Shader) {
		var sx = 1.0;
		var sy = 1.0;
		var x = 0.0;
		var y = 0.0;

		var vertices = _vertexBufferQuad.lock();
		setQuadVerticesToBuffer(vertices, x, y, source.width * sx, source.height * sy);
		_vertexBufferQuad.unlock();

		var g = target.g4;
		var projectionMatrix = _fastMatrixTmp.orto(0, target.width, target.height, 0);

		g.begin();
		g.clear(kha.Color.Transparent);

		drawInternal(
			g,
			projectionMatrix,
			_vertexBufferQuad,
			_indexBufferQuad,
			shader,
			source,
			_textureParametersDefault,
			_blendingDefault,
			null,
			6
		);

		g.end();
	}

	public inline function checkErrors() {
		assert(states.length == 0, 'RenderContext has unfinished states:[${getStateNames()}], make sure you end all states');
		assert(!_inGeometryMode, 'RenderContext: has unfinished beginGeometry');
	}

	#if !clay_no_assertions
	function getStateNames() {
		var stateNames = [];
		for (s in states) {
			stateNames.push('${s.id}:${s.target.id}');
		}
		return stateNames.join(',');
	}
	#end

	inline function beginInternal(state:RenderState) {
		var g = state.target.image.g4;
		g.begin();
		g.clear(state.clearColor);
	}

	inline function endInternal(state:RenderState) {
		var g = state.target.image.g4;
		g.end();
	}

	inline function setQuadVerticesToBuffer(buffer:Float32Array, x:Float, y:Float, w:Float, h:Float) {
		var index:Int = 0;
		buffer.set(index + 0, x);
		buffer.set(index + 1, y);

		index += 8;
		buffer.set(index + 0, x + w);
		buffer.set(index + 1, y);

		index += 8;
		buffer.set(index + 0, x + w);
		buffer.set(index + 1, y + h);

		index += 8;
		buffer.set(index + 0, x);
		buffer.set(index + 1, y + h);
	}

	inline function setOrtoFastMatrix3(matrix:FastMatrix3, width:Int, height:Int):FastMatrix3 {
		if (kha.Image.renderTargetsInvertedY()) {
			matrix.orto(0, width, 0, height);
		} else {
			matrix.orto(0, width, height, 0);
		}
		return matrix;
	}

	inline function setOrtoMatrix(matrix:Matrix, width:Int, height:Int):Matrix {
		if (kha.Image.renderTargetsInvertedY()) {
			matrix.orto(0, width, 0, height);
		} else {
			matrix.orto(0, width, height, 0);
		}
		return matrix;
	}

	inline function uploadBuffers(vertexBuffer:VertexBuffer, indexBuffer:IndexBuffer) {
		var vCount = _vertsDraw * 8;
		var verts = vertexBuffer.lock();
		var i:Int = 0;
		while(i < vCount) {
			verts.set(i, _vertices.get(i));
			i++;
		}
		vertexBuffer.unlock();
		
		var ind = indexBuffer.lock();
		i = 0;
		while(i < _indicesDraw) {
			ind.set(i, _indices.get(i));
			i++;
		}
		indexBuffer.unlock();
	}

	inline function draw(vertexbuffer:VertexBuffer, indexbuffer:IndexBuffer, count:Int) {
		var g = currentState.target.image.g4;
		var texture = getTexture();
		var clipRect = getClipRect();
		var viewport = getViewport();
		g.viewport(Std.int(viewport.x), Std.int(viewport.y), Std.int(viewport.w), Std.int(viewport.h));
		drawInternal(
			g,
			currentState.projectionMatrix,
			vertexbuffer,
			indexbuffer,
			currentState.shader,
			texture,
			currentState.textureParameters,
			currentState.blending,
			clipRect,
			count
		);

		#if !no_debug_console
		if(stats != null) {
			stats.drawCalls++;
		}
		#end
	}

	inline function popState() {
		var lastState = states.pop();
		currentState = getLastState();
		lastState.reset();
		statesPool.put(lastState);
	}

	inline function pushState(target:Texture) {
		currentState = statesPool.get();
		currentState.target = target;
		states.push(currentState);
	}

	inline function getLastState():RenderState {
		var state:RenderState = null;
		if(states.length > 0) {
			state = states[states.length-1];
		}
		return state;
	}

	inline function initState() {
		currentState.textureParameters = _textureParametersDefault;
		currentState.blending = _blendingDefault;
		currentState.color = _colorDefault;
		currentState.clearColor = kha.Color.Transparent;
	}

	inline function getTexture():Texture {
		return currentState.texture != null ? currentState.texture : _textureBlank;
	}

	inline function getClipRect():Rectangle {
		return currentState.clipRect != null ? currentState.clipRect : currentState.clipBounds;
	}

	inline function getViewport():Rectangle {
		return currentState.viewport != null ? currentState.viewport : _viewportDefault;
	}

	inline function drawInternal(
		g:Graphics, 
		projectionMatrix:FastMatrix3,
		vertexbuffer:VertexBuffer, 
		indexbuffer:IndexBuffer, 
		shader:Shader, 
		texture:Texture, 
		textureParameters:TextureParameters,
		blending:Blending, 
		clipRect:Rectangle, 
		count:Int
	) {
		if(clipRect != null) {
			g.scissor(Std.int(clipRect.x), Std.int(clipRect.y), Std.int(clipRect.w), Std.int(clipRect.h));
		}

		var textureUniform = shader.setTexture('tex', texture);
		shader.setTextureParameters('tex', textureParameters);
		shader.setMatrix3('mvpMatrix', projectionMatrix);

		shader.setBlending(
			blending.blendSrc, blending.blendDst, blending.blendOp, 
			blending.alphaBlendSrc, blending.alphaBlendDst, blending.alphaBlendOp
		);

		shader.use(g);
		shader.apply(g);

		g.setVertexBuffer(vertexbuffer);
		g.setIndexBuffer(indexbuffer);

		g.drawIndexedVertices(0, count);

		g.setTexture(textureUniform.location, null);

		if(clipRect != null) {
			g.disableScissor();
		}
	}

	function getVertexBuffer(vertsCount:Int):VertexBuffer {
		var p2 = PowerOfTwo.get(vertsCount);
		var idx = Mathf.log2(p2);
		var buffer = _vertexBuffers[idx];

		if(buffer == null) {
			var shader = _renderer.shaders.get('textured');
			buffer = new VertexBuffer(p2, shader.pipeline.inputLayout[0], Usage.DynamicUsage);
			_vertexBuffers[idx] = buffer;
		}

		return buffer;
	}

	function getIndexBuffer(idxCount:Int):IndexBuffer {
		var p2 = PowerOfTwo.get(idxCount);
		var idx = Mathf.log2(p2);
		var buffer = _indexBuffers[idx];

		if(buffer == null) {
			buffer = new IndexBuffer(p2, Usage.DynamicUsage);
			_indexBuffers[idx] = buffer;
		}

		return buffer;
	}

}
