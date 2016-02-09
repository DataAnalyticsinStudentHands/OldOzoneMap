package LatLongInterpolation_testing;

/* 
 * DataScanner
 * 
 * This is a two dimensional double data scanner, written for replacing CSV data scanner from file.
 * Since this is a compatibility layer, the functions are made similar to typical java.util.scanner
 * The data will be fetched on row-major fashion, with column pointer moving faster than row
 * pointer.
 * 
 * Author: Sushil Joshi (sjoshi4@mail.uh.edu)
 * 
 */
public class DataScanner {
	private double[][] data;
	private int currentLine;
	private int currentPosition;	
	private int columnLength;
	public int dataLength;
	
	public DataScanner () {
		currentLine = -1;
		currentPosition = -1;
		dataLength = 0;
		columnLength = 0;
	}
	
	public DataScanner(double[][] sourceData) {
		currentLine = -1;
		currentPosition = -1;
		dataLength = 0;
		columnLength = 0;
		setDataSource(sourceData);
	}
	
	public void setDataSource(double[][] sourceData) {
		data = sourceData;
		dataLength = data.length;
		if (dataLength > 0) {
			columnLength = data[0].length;
			currentLine = 0;
			if (columnLength > 0) {
				currentPosition = 0;
			}
		}
	}
	
	public void nextLine() {
		currentLine++;
		currentPosition = 0;
	}
	
	public boolean hasNextDouble() {
		boolean status = false;
		if (currentLine < dataLength && currentPosition < columnLength) {
			// since the data source is already an array of double, we don't need to enforce
			// data type check
			status = true;
		}
		return status;
	}
	
	public double nextDouble() {
		return data[currentLine][currentPosition++];
	}
}
