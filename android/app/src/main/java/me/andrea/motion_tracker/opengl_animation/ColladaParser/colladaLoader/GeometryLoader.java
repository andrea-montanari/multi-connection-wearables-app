package me.andrea.motion_tracker.opengl_animation.ColladaParser.colladaLoader;

import android.opengl.Matrix;
import android.util.Log;

import me.andrea.motion_tracker.opengl_animation.Animation.utils.Vector2f;
import me.andrea.motion_tracker.opengl_animation.Animation.utils.Vector3f;
import me.andrea.motion_tracker.opengl_animation.ColladaParser.dataStructures.MeshData;
import me.andrea.motion_tracker.opengl_animation.ColladaParser.dataStructures.Vertex;
import me.andrea.motion_tracker.opengl_animation.ColladaParser.dataStructures.VertexSkinData;

import java.util.ArrayList;
import java.util.List;

import me.andrea.motion_tracker.opengl_animation.ColladaParser.xmlParser.XmlNode;

/**
 * Loads the mesh data for a model from a collada XML file.
 * @author Karl
 *
 */
public class GeometryLoader {

	private static final float rotationAngle = -90f;
	private static float[] CORRECTION = new float[16];

	private final XmlNode meshData;

	private final List<VertexSkinData> vertexWeights;
	
	private float[] verticesArray;
	private float[] normalsArray;
	private float[] texturesArray;
	private int[] indicesArray;
	private int[] jointIdsArray;
	private float[] weightsArray;

	List<Vertex> vertices = new ArrayList<Vertex>();
	List<Vector2f> textures = new ArrayList<Vector2f>();
	List<Vector3f> normals = new ArrayList<Vector3f>();
	List<Integer> indices = new ArrayList<Integer>();
	
	public GeometryLoader(XmlNode geometryNode, List<VertexSkinData> vertexWeights) {
		this.vertexWeights = vertexWeights;
		this.meshData = geometryNode.getChild("geometry").getChild("mesh");
		Matrix.setIdentityM(CORRECTION, 0);
		Matrix.rotateM(CORRECTION, 0, rotationAngle, 1, 0, 0);
	}
	
	public MeshData extractModelData(){
		readPositions();
		List<XmlNode> trianglesList = meshData.getChildren("triangles");
		for (XmlNode triangle: trianglesList) {
			assembleVertices(triangle);
			readNormals(triangle);
			readTextureCoords(triangle);
		}
		removeUnusedVertices();
		initArrays();
		convertDataToArrays();
		convertIndicesListToArray();
		return new MeshData(verticesArray, texturesArray, normalsArray, indicesArray, jointIdsArray, weightsArray);
	}

	private void readPositions() {
		String positionsId = meshData.getChild("vertices").getChild("input").getAttribute("source").substring(1);
		XmlNode positionsData = meshData.getChildWithAttribute("source", "id", positionsId).getChild("float_array");
		int count = Integer.parseInt(positionsData.getAttribute("count"));
		String[] posData = positionsData.getData().split(" ");
		for (int i = 0; i < count/3; i++) {
			float x = Float.parseFloat(posData[i * 3]);
			float y = Float.parseFloat(posData[i * 3 + 1]);
			float z = Float.parseFloat(posData[i * 3 + 2]);
			float[] position = {x, y, z, 1};
			float[] positionCorrected = new float[4];
			Matrix.multiplyMV(positionCorrected, 0, CORRECTION, 0, position, 0);
			vertices.add(new Vertex(vertices.size(), new Vector3f(positionCorrected[0], positionCorrected[1], positionCorrected[2]), vertexWeights.get(vertices.size())));
		}
	}

	private void readNormals(XmlNode triangle) {
		String normalsId = triangle.getChildWithAttribute("input", "semantic", "NORMAL")
				.getAttribute("source").substring(1);
		XmlNode normalsData = meshData.getChildWithAttribute("source", "id", normalsId).getChild("float_array");
		int count = Integer.parseInt(normalsData.getAttribute("count"));
		String[] normData = normalsData.getData().split(" ");
		for (int i = 0; i < count/3; i++) {
			float x = Float.parseFloat(normData[i * 3]);
			float y = Float.parseFloat(normData[i * 3 + 1]);
			float z = Float.parseFloat(normData[i * 3 + 2]);
			float[] norm = {x, y, z, 0f};
			float[] normCorrected = new float[4];
			Matrix.multiplyMV(normCorrected, 0, CORRECTION, 0, norm, 0);
			normals.add(new Vector3f(normCorrected[0], normCorrected[1], normCorrected[2]));
		}
	}

	private void readTextureCoords(XmlNode triangle) {
		String texCoordsId = triangle.getChildWithAttribute("input", "semantic", "TEXCOORD")
				.getAttribute("source").substring(1);
		XmlNode texCoordsData = meshData.getChildWithAttribute("source", "id", texCoordsId).getChild("float_array");
		int count = Integer.parseInt(texCoordsData.getAttribute("count"));
		String[] texData = texCoordsData.getData().split(" ");
		for (int i = 0; i < count/2; i++) {
			float s = Float.parseFloat(texData[i * 2]);
			float t = Float.parseFloat(texData[i * 2 + 1]);
			textures.add(new Vector2f(s, t));
		}
	}
	
	private void assembleVertices(XmlNode triangle){
		Log.v("Geometry loader", "Triangles for: " + triangle.getAttribute("material"));
		int typeCount = triangle.getChildren("input").size();
		String[] indexData = triangle.getChild("p").getData().split(" ");
		Log.v("Geometry loader", "Read vertices");
		for(int i=0;i<indexData.length/typeCount;i++){
			int positionIndex = Integer.parseInt(indexData[i * typeCount]);
			int normalIndex = Integer.parseInt(indexData[i * typeCount + 1]);
			int texCoordIndex = Integer.parseInt(indexData[i * typeCount + 2]);
			processVertex(positionIndex, normalIndex, texCoordIndex);
		}
	}
	

	private Vertex processVertex(int posIndex, int normIndex, int texIndex) {
		Vertex currentVertex = vertices.get(posIndex);
		if (!currentVertex.isSet()) {
			currentVertex.setTextureIndex(texIndex);
			currentVertex.setNormalIndex(normIndex);
			indices.add(posIndex);
			return currentVertex;
		} else {
			return dealWithAlreadyProcessedVertex(currentVertex, texIndex, normIndex);
		}
	}

	private int[] convertIndicesListToArray() {
		this.indicesArray = new int[indices.size()];
		for (int i = 0; i < indicesArray.length; i++) {
			indicesArray[i] = indices.get(i);
		}
		return indicesArray;
	}

	private float convertDataToArrays() {
		float furthestPoint = 0;
		for (int i = 0; i < vertices.size(); i++) {
			Vertex currentVertex = vertices.get(i);
			if (currentVertex.getLength() > furthestPoint) {
				furthestPoint = currentVertex.getLength();
			}
			Vector3f position = currentVertex.getPosition();
			Vector2f textureCoord = textures.get(currentVertex.getTextureIndex());
			Vector3f normalVector = normals.get(currentVertex.getNormalIndex());
			verticesArray[i * 3] = position.x;
			verticesArray[i * 3 + 1] = position.y;
			verticesArray[i * 3 + 2] = position.z;
			texturesArray[i * 2] = textureCoord.x;
			texturesArray[i * 2 + 1] = 1 - textureCoord.y;
			normalsArray[i * 3] = normalVector.x;
			normalsArray[i * 3 + 1] = normalVector.y;
			normalsArray[i * 3 + 2] = normalVector.z;
			VertexSkinData weights = currentVertex.getWeightsData();
			jointIdsArray[i * 3] = weights.jointIds.get(0);
			jointIdsArray[i * 3 + 1] = weights.jointIds.get(1);
			jointIdsArray[i * 3 + 2] = weights.jointIds.get(2);
			weightsArray[i * 3] = weights.weights.get(0);
			weightsArray[i * 3 + 1] = weights.weights.get(1);
			weightsArray[i * 3 + 2] = weights.weights.get(2);

		}
		return furthestPoint;
	}

	private Vertex dealWithAlreadyProcessedVertex(Vertex previousVertex, int newTextureIndex, int newNormalIndex) {
		if (previousVertex.hasSameTextureAndNormal(newTextureIndex, newNormalIndex)) {
			indices.add(previousVertex.getIndex());
			return previousVertex;
		} else {
			Vertex anotherVertex = previousVertex.getDuplicateVertex();
			if (anotherVertex != null) {
				return dealWithAlreadyProcessedVertex(anotherVertex, newTextureIndex, newNormalIndex);
			} else {
				Vertex duplicateVertex = new Vertex(vertices.size(), previousVertex.getPosition(), previousVertex.getWeightsData());
				duplicateVertex.setTextureIndex(newTextureIndex);
				duplicateVertex.setNormalIndex(newNormalIndex);
				previousVertex.setDuplicateVertex(duplicateVertex);
				vertices.add(duplicateVertex);
				indices.add(duplicateVertex.getIndex());
				return duplicateVertex;
			}

		}
	}
	
	private void initArrays(){
		this.verticesArray = new float[vertices.size() * 3];
		this.texturesArray = new float[vertices.size() * 2];
		this.normalsArray = new float[vertices.size() * 3];
		this.jointIdsArray = new int[vertices.size() * 3];
		this.weightsArray = new float[vertices.size() * 3];
	}

	private void removeUnusedVertices() {
		for (Vertex vertex : vertices) {
			vertex.averageTangents();
			if (!vertex.isSet()) {
				vertex.setTextureIndex(0);
				vertex.setNormalIndex(0);
			}
		}
	}
	
}