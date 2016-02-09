/*
 * Driver code that gets invoked from PHP layer using PHP Java Bridge.
 * 
 * Author: Sushil Joshi (sjoshi4@mail.uh.edu)
 */
package LatLongInterpolation_testing;

import java.util.ArrayList;
import java.util.List;
import java.util.HashMap;

public class LatLngDriver {	
    /**
     *  A hash containing key value pair of identifier and limit of different band. This is used
     * to make discrete regions in grid to produce regions for contour calculation 
    **/
    private HashMap<Integer, Double> discreteBand;
	public HashMap<String, Double> gridExtent;
	private boolean writeDebugImages = true;
	
	/**
	 * Constructor
	 * Initialize private variables with some values
	 */
	public LatLngDriver () 
	{
		initDiscreteBand();
		gridExtent = new HashMap<String, Double>();
		gridExtent.put("latmin", 0.0);
		gridExtent.put("latmax", 0.0);
		gridExtent.put("longmin", 0.0);
		gridExtent.put("longmax", 0.0);
	}
	  
	/**
	 * Overloaded Constructor
	 * Initialize private variables with some values
	 */
	public LatLngDriver (HashMap<Integer, Double> discreteBand) 
	{
		this.discreteBand = discreteBand;
		gridExtent = new HashMap<String, Double>();
		gridExtent.put("latmin", 0.0);
		gridExtent.put("latmax", 0.0);
		gridExtent.put("longmin", 0.0);
		gridExtent.put("longmax", 0.0);
	}
	
	/**
	 * Overloaded Constructor
	 * Initialize private variables with some values
	 */
	public LatLngDriver (HashMap<Integer, Double> discreteBand, HashMap<String, Double> gridExtent) 
	{
		this.discreteBand = discreteBand;
		this.gridExtent = gridExtent;
	}
	
	/*
	 * setWriteDebugImages
	 * 
	 *  Configure whether to write output debug images or not
	 */
	public void setWriteDebugImages(boolean debug) {
        writeDebugImages = debug;
    }
	
    /* 
     * drive
     * 
     * Driver function to take data input from PHP-Java-Bridge and do the interpolation
     *  
     */
    public List<List<double []>> drive(double[][] oStations, double[][] wStations, double[][] ozValues, double[][] wSpdValues, double[][] wDirValues, String outFile, double step)
    {

    	Gas ozone = new Gas();
    	if (!writeDebugImages) {
    	    ozone.setWriteDebugImages(false);
    	}
    	Wind wind = new Wind();
    	ozone.loadStations(oStations);
    	wind.loadStations(wStations);
    	wind.setValueSources(wSpdValues, wDirValues);
    	ozone.setWind(wind);
    	ozone.validate();
    	ozone.setValueSource(ozValues);
    	ozone.loadAvailableValues();
    	
    	gridExtent.put("latmin",step*((int) (ozone.latmin/step)));
    	gridExtent.put("latmax", step*((int) (ozone.latmax/step)+1));
    	gridExtent.put("longmin", step*((int) (ozone.lonmin/step)));
    	gridExtent.put("longmax", step*((int) (ozone.lonmax/step)+1));
    	
    	try {
    		return ozone.filePrintGrid(outFile, step, discreteBand);
    	} catch (Exception e) {
    		System.out.println("Exception:::::" + e.getMessage());
    		List<List<double []>> emptyValue = new ArrayList<List<double []>>();
    		return emptyValue;
    	}
    }
       
    /* 
     * overloaded function that uses test data for running algorithm
     * 
     */
    public List<List<double []>> drive()
    {
    	return drive(ozoneStationTestData(), windStationTestData(), ozoneValuesTestData(), windSpeedTestData(), windDirectionTestData(), "/tmp/test6.csv", 0.01);
    }
    
    /*
     * initDiscreteBand
     * 
     * Initialize default discretization parameters for contour calculation
     */
    private void initDiscreteBand() 
    {
    	discreteBand = new HashMap<Integer, Double>();
		//int[] key = {50, 100, 150, 200, 300, 500};
		//double[] limits = {37.5, 75, 112.5, 150, 225, 375};
		
		int[] key = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180};
		double[] limits = {32.5, 37.5, 42.5, 70, 75, 80, 107.5, 112.5, 117.5, 145, 150, 155, 220, 225, 230, 370, 375, 380};
		for (int i=0; i<key.length; i++) {
			
			discreteBand.put(key[i], limits[i]);
		}
    }
    
    public List<List<double []>> getContours()
    {
    	return getContours(ozoneStationTestData(), windStationTestData(), ozoneValuesTestData(), windSpeedTestData(), windDirectionTestData(), 0.01);
    }
    
    public List<List<double []>> getContours(double[][] oStations, double[][] wStations, double[][] ozValues, double[][] wSpdValues, double[][] wDirValues, double step)
    {
    	Gas ozone = new Gas();
        if (!writeDebugImages) {
            ozone.setWriteDebugImages(false);
        }
    	Wind wind = new Wind();
    	ozone.loadStations(oStations);
    	wind.loadStations(wStations);
    	wind.setValueSources(wSpdValues, wDirValues);
    	ozone.setWind(wind);
    	ozone.validate();
    	ozone.setValueSource(ozValues);
    	ozone.loadAvailableValues();
    	
    	if (gridExtent.get("latmin") == 0.0 && gridExtent.get("latmax") == 0.0 && gridExtent.get("longmin") == 0.0 && gridExtent.get("longmax") == 0.0) {
    		gridExtent.put("latmin",step*((int) (ozone.latmin/step)));
    		gridExtent.put("latmax", step*((int) (ozone.latmax/step)+1));
    		gridExtent.put("longmin", step*((int) (ozone.lonmin/step)));
    		gridExtent.put("longmax", step*((int) (ozone.lonmax/step)+1));
    	} else {
    		ozone.setLatLngExtent(gridExtent);
    	}
    	
    	try {
    		return ozone.getContours(step, discreteBand);
    	} catch (Exception e) {
    		System.out.println("Exception:::::" + e.getMessage());
    		List<List<double []>> emptyValue = new ArrayList<List<double []>>();
    		return emptyValue;
    	}
    }
    
    public double[][] getGridData(double[][] oStations, double[][] wStations, double[][] ozValues, double[][] wSpdValues, double[][] wDirValues, double step) {
    	double[][] gridData;
    	Gas ozone = new Gas();
        if (!writeDebugImages) {
            ozone.setWriteDebugImages(false);
        }
    	Wind wind = new Wind();
    	ozone.loadStations(oStations);
    	wind.loadStations(wStations);
    	wind.setValueSources(wSpdValues, wDirValues);
    	ozone.setWind(wind);
    	ozone.validate();
    	ozone.setValueSource(ozValues);
    	ozone.loadAvailableValues();
    	
    	// Decide whether to set gridExtent to values passed from caller space or to use the extent
    	// calculated from available stations
    	if (gridExtent.get("latmin") == 0.0 && gridExtent.get("latmax") == 0.0 && gridExtent.get("longmin") == 0.0 && gridExtent.get("longmax") == 0.0) {
    		gridExtent.put("latmin",step*((int) (ozone.latmin/step)));
    		gridExtent.put("latmax", step*((int) (ozone.latmax/step)+1));
    		gridExtent.put("longmin", step*((int) (ozone.lonmin/step)));
    		gridExtent.put("longmax", step*((int) (ozone.lonmax/step)+1));
    	} else {
    		ozone.setLatLngExtent(gridExtent);
    	}
    	
    	gridData = ozone.getGrid(step);
    	return gridData;
    }
    
    /*
     * getGridData
     * Overloaded function that uses test data to run the algorithm 
     */
    public double[][] getGridData() {
    	return getGridData(ozoneStationTestData(), windStationTestData(), ozoneValuesTestData(), windSpeedTestData(), windDirectionTestData(), 0.01);
    }
    
    /* Snapshot of test data
     * Following methods generate test data for one timestamp (unspecified timestamp).
     */
    public double[][] ozoneStationTestData() {
        double[][] d = {
            {29.767778,-95.220556},
            {29.901111,-95.326111},
            {29.8025,-95.125556},
            {30.039444,-95.673889},
            {29.67,-95.128333},
            {29.583056,-95.015556},
            {29.695833,-95.499167},
            {30.350278,-95.425},
            {29.735,-95.315556},
            {29.520278,-95.3925},
            {29.733611,-95.2575},
            {29.828056,-95.284167},
            {29.625556,-95.267222},
            {29.834167,-95.489167},
            {29.623889,-95.474167},
            {29.723333,-95.635833},
            {29.752778,-95.350278},
            {29.686389,-95.294722},
            {29.858611,-95.160278},
            {29.733056,-94.984722},
            {29.920833,-95.068333},
            {29.833056,-95.656944},
            {29.655278,-95.009722},
            {30.038056,-95.381111},
            {29.589444,-95.353611},
            {29.810556,-95.806111},
            {29.961944,-95.235},
            {30.011667,-95.5225},
            {29.761667,-95.538056},
            {29.548889,-95.185278},
            {29.525556,-95.070556},
            {29.583333,-95.105},
            {29.821389,-94.99},
            {29.148889,-95.765},
            {29.313611,-95.201389},
            {29.402222,-94.946389},
            {29.764444,-95.077778},
            {29.043611,-95.472778},
            {29.254444,-94.861111}
        };
        return d;
    }
    public double[][] windStationTestData() {
            double[][] d = {
            {29.767778,-95.220556},
            {29.901111,-95.326111},
            {29.010833,-95.397778},
            {29.8025,-95.125556},
            {30.039444,-95.673889},
            {29.67,-95.128333},
            {29.583056,-95.015556},
            {29.9475,-95.542778},
            {29.695833,-95.499167},
            {30.350278,-95.425},
            {29.735,-95.315556},
            {29.520278,-95.3925},
            {29.546111,-94.787222},
            {29.615,-95.018056},
            {29.770556,-95.031111},
            {29.734167,-95.238056},
            {29.706111,-95.261111},
            {30.058333,-95.189722},
            {29.733611,-95.2575},
            {29.8075,-95.293611},
            {29.828056,-95.284167},
            {29.625556,-95.267222},
            {29.834167,-95.489167},
            {29.623889,-95.474167},
            {29.723333,-95.635833},
            {29.752778,-95.350278},
            {29.686389,-95.294722},
            {29.858611,-95.160278},
            {29.733056,-94.984722},
            {29.920833,-95.068333},
            {29.833056,-95.656944},
            {30.054722,-95.185},
            {29.655278,-95.009722},
            {30.038056,-95.381111},
            {29.589444,-95.353611},
            {29.810556,-95.806111},
            {29.961944,-95.235},
            {30.011667,-95.5225},
            {29.761667,-95.538056},
            {30.057778,-95.061389},
            {29.548889,-95.185278},
            {29.525556,-95.070556},
            {29.583333,-95.105},
            {29.765278,-95.181111},
            {29.381389,-94.940833},
            {29.368611,-94.915278},
            {29.821389,-94.99},
            {29.148889,-95.765},
            {29.313611,-95.201389},
            {29.402222,-94.946389},
            {29.380833,-94.93},
            {29.694722,-95.252778},
            {29.701944,-95.257222},
            {29.706111,-95.255},
            {29.7025,-95.254444},
            {29.376111,-94.910278},
            {29.7175,-95.341389},
            {29.574167,-95.649722},
            {29.387778,-95.041389},
            {30.236111,-95.483056},
            {30.058056,-94.978056},
            {29.764444,-95.077778},
            {29.043611,-95.472778},
            {29.684444,-95.253611},
            {29.385,-94.931389},
            {29.718611,-95.259722},
            {29.254444,-94.861111},
            {29.776111,-95.105},
            {29.716389,-95.2225},
            {29.270278,-94.864167},
            {30.356667,-95.413889},
            {30.743889,-95.586111}
        };
        return d;
    }
    public double[][] ozoneValuesTestData() {
        double[][] d = {
            {47.48205,44.47212,43.13139,53.11434,48.64448,48.29836,47.61749,52.00019,43.58073,45.39555,36.83485,41.94279,41.14822,43.80618,42.55346,47.17773,45.21135,48.65171,43.45,47.65,49.45,51.85,51.05,51.5,48.9,43.95,53.05,48.4,48.6,46.65,46.65,46.45,52.42138,44.07763,42.56207,46.63694,43.76824,44.811,42.41778},
            {47.19534,44.52183,42.16992,53.93517,48.44464,48.14949,47.17215,51.19709,42.88581,45.09325,35.07041,41.07814,42.0471,44.42051,42.83874,47.42235,45.16167,48.22911,44,46.9,52.45,51.3,51.05,52.4,48.55,42.3,51.05,49.1,49.5,46.05,47.1,45.55,51.79291,43.79007,41.89531,45.52433,41.48648,44.66118,42.50992},
            {47.29091,44.91949,41.56267,54.9099,47.69524,48.24874,46.18253,51.34767,43.23327,45.44594,34.21339,42.07931,41.99715,45.36562,42.07801,47.71589,42.52848,47.54239,44.35,46.8,53.3,51.75,50.55,52.2,48.85,34.4,53.6,49.65,49.35,47.1,47.75,45.65,50.87436,43.88592,41.32379,46.54422,22.24713,44.31161,41.86491},
            {46.71749,45.0189,43.53622,54.75599,47.7452,47.45479,45.53928,52.20095,43.08436,45.49632,40.16209,40.39553,40.14948,45.08208,39.93845,45.66113,44.61515,48.17629,44.75,43.1,53.2,51.05,49.55,52,48.55,41.3,54.05,49.85,49,46.45,48.55,45.35,50.82602,43.93385,41.56192,46.26607,46.93158,43.41273,42.09527},
            {46.43079,45.56569,43.94106,55.37161,48.39468,48.05025,45.24238,52.70289,41.84345,44.99249,37.84311,41.89728,42.34671,43.00283,42.1731,46.78635,43.12467,48.07064,43.75,0.15,53.3,51.2,50.55,51.55,48.3,42.9,53.55,50.45,47.7,47.5,49.8,45.2,50.68098,43.93385,42.18106,45.70976,47.0353,43.16304,42.27956},
            {45.66623,45.91365,45.35796,55.93593,48.34472,47.20668,43.85691,53.10443,42.83618,45.14364,37.59104,42.71642,40.39916,43.71167,43.26665,48.64542,43.22404,47.80651,46.65,425,54.3,50.55,50.05,52.2,48.35,43.3,54.55,48.9,46.6,46.4,49.3,46.7,49.56907,44.31727,43.27647,44.92167,26.91436,42.7136,42.556}
        };
        return d;
    }
    public double[][] windSpeedTestData() {
        double[][] d = {
            {11.2,11.4,16.3,14.4,9.5,13,11.9,11.2,13.2,10.3,10.5,17.5,17.4,18.3,14.9,12.5,15.1,-1,13.7,10.9,-1,-1,-1,11.1,7.2,-1,13.1,-1,-1,-1,-1,-1,21.8,-1,-1,16.8,10.7,-1,-1,-1,14.8,-1,11.2,12.4,15.1,15.2,13.4,16.7,23.6,10.9,-1,4.338,4.95081,8.04,11.62,10.21,-1,-1,-1,-1,-1,22.8,16.3,11.2,13.4,9.2,9.9,9.6,14.4,14.7443,12.3938,7.591},
            {9.4,11.8,15.5,10.3,12,13.1,11.9,9.1,11.8,9.6,7.5,15.8,16.7,18.5,13.2,9.4,13.2,-1,13.4,9.3,-1,-1,-1,11.6,9.8,-1,11.6,-1,-1,-1,-1,-1,21.2,-1,-1,15.9,12.3,-1,-1,-1,11.9,-1,11,11.9,15.9,16.3,14.4,15.8,22.6,9.3,-1,4.69405,5.28439,8.91,11.62,10.22,-1,-1,-1,-1,-1,22.8,18,10.1,12.4,10.3,9.2,8.4,14.5,14.0325,14.7254,8.0351},
            {9.3,10.7,16.2,12.2,12.5,13,12.4,9.7,11.9,11,9.9,18.6,18.1,18.9,15.1,8.4,11.6,-1,13.1,9.2,-1,-1,-1,8.6,8.2,-1,12.7,-1,-1,-1,-1,-1,22.3,-1,-1,13.8,12.2,-1,-1,-1,12.2,-1,13.8,13.6,14.1,17.5,13.7,16.7,23.6,9.6,-1,4.58527,4.49048,10.27,12.21,8.83,-1,-1,-1,-1,-1,22.7,16.9,11.3,9.9,10.3,8.9,8.7,14,14.5143,11.4909,10.3322},
            {9.3,9.8,13.6,13.2,12.4,11.8,15.7,10.3,14.6,14.7,11,17.7,15.9,18.9,11.5,11,13.8,-1,13.2,12.7,-1,-1,-1,10.3,8.5,-1,12.3,-1,-1,-1,-1,-1,19.7,-1,-1,18.4,11.3,-1,-1,-1,10.8,-1,12.5,12.9,15,14.8,14,16.9,23.1,10.6,-1,4.16671,5.29657,9.46,9.09,10.82,-1,-1,-1,-1,-1,24.9,16.8,8.6,10.5,9.9,10.2,7.4,14.2,14.7405,12.1492,11.2038},
            {9.8,10.1,16.5,12.1,9.3,14.4,16.3,12.1,12.7,12.2,7.4,19.2,16.7,18.4,14.8,11,13.1,-1,14.1,11.6,-1,-1,-1,12.8,9.2,-1,10.7,-1,-1,-1,-1,-1,19.3,-1,-1,16.4,12.4,-1,-1,-1,14.7,-1,11.8,11.6,13.2,16.1,15.7,17.4,19.4,8.3,-1,4.25673,4.43535,6.79,11.32,11.56,-1,-1,-1,-1,-1,25.9,17.8,11.8,11.9,8.8,10.3,7.7,10,12.8912,12.1412,9.4179},
            {11,12,14.2,12.7,11.9,11.8,12.6,9.7,11.2,12.5,9.7,18.8,17.3,18.8,14.2,13.7,14.7,-1,15.1,9.6,-1,-1,-1,9.4,10.7,-1,13.8,-1,-1,-1,-1,-1,20.4,-1,-1,16.9,11.3,-1,-1,-1,14.1,-1,14.3,12.3,14.2,13.7,12.6,15.8,22.3,9.2,-1,-1,5.24366,8.02,8.48,10.87,-1,-1,-1,-1,-1,27.1,14,12.3,10.6,8,9.7,8.7,15.4,12.8949,12.6078,9.4128}
        };
        return d;
    }
    public double[][] windDirectionTestData() {
        double[][] d = {
            {151.60001,155.8,159.89999,139,171.8,154.89999,147.3,164,150.5,138.7,163.2,147.39999,157.39999,134.89999,121,146.7,163.3,-1,175.89999,183.3,-1,-1,-1,159.8,166.10001,-1,155.39999,-1,-1,-1,-1,-1,151.7,-1,-1,82.6,163.8,-1,-1,-1,169.39999,-1,151.89999,152.5,180.7,161.2,165.3,142.2,163.89999,178.60001,-1,159.119,130.726,153.89999,159.3,157.3,-1,-1,-1,-1,-1,157.3,139.39999,153,144.39999,145.10001,143.2,132.8,154.39999,142.203,152.95799,153.698},
            {170,131.7,166.8,136.89999,165.39999,164.60001,150.3,163.8,151.10001,157.2,166.10001,160.2,153.3,132.60001,124.1,164.8,164.39999,-1,187.3,176.10001,-1,-1,-1,161.7,173.10001,-1,163.7,-1,-1,-1,-1,-1,151.60001,-1,-1,82.6,144.2,-1,-1,-1,160.3,-1,165.60001,137.39999,189.8,160.60001,154.89999,148.60001,159.3,180,-1,169.119,158.877,186.10001,151.10001,163.10001,-1,-1,-1,-1,-1,155.8,142.7,152.8,146.8,170.10001,144.39999,133,158.10001,148.26199,149.157,163.744},
            {154.60001,161.5,170.7,144.2,156.8,155.2,161.3,177.39999,152.10001,169.7,164.5,157.2,153.39999,133,125,179.10001,152.3,-1,178.7,175.7,-1,-1,-1,162.60001,172.5,-1,156.2,-1,-1,-1,-1,-1,150.2,-1,-1,82.7,143.2,-1,-1,-1,164.8,-1,165.8,149.5,177.2,161.2,160.2,152.8,157.10001,178,-1,154.687,155.549,171.60001,156.39999,159.8,-1,-1,-1,-1,-1,159.10001,152.39999,151.7,156.7,159.2,144.8,136.5,165.8,149.01601,152.32001,179.379},
            {151.39999,156.2,173.8,139.89999,169.7,149.89999,170.89999,148.2,140.7,170.10001,176.5,161,152.39999,133.8,139.7,156.10001,175,-1,187.60001,163.60001,-1,-1,-1,162.5,172.5,-1,174.10001,-1,-1,-1,-1,-1,147.8,-1,-1,82.7,144.89999,-1,-1,-1,164.39999,-1,158.3,143.10001,181.7,163.5,154.5,144.89999,158.60001,173,-1,162.89,159.20599,168.39999,164.89999,161.10001,-1,-1,-1,-1,-1,161.2,151.89999,173.2,146.7,158.2,141,133.89999,147.60001,147.375,141.644,168.073},
            {162.60001,159.39999,160.3,142.5,148.89999,167.7,170.10001,161,148.8,183.2,172,142.39999,154.3,137.39999,141.2,168.89999,181.39999,-1,170.7,149.2,-1,-1,-1,157.5,163.3,-1,144.5,-1,-1,-1,-1,-1,146,-1,-1,82.7,143.39999,-1,-1,-1,160.7,-1,151,144.60001,173.8,162.60001,151.8,156.2,161.2,185.39999,-1,168.36099,168.104,165.3,165,149.89999,-1,-1,-1,-1,-1,154.5,153.39999,160,150,166.2,140.5,133.39999,161.60001,146.57201,141.166,168.68401},
            {166.39999,147.89999,159.5,134.2,180.3,152,162.39999,170.60001,141.3,177.39999,174.10001,146.89999,152.5,139.60001,137,149.89999,169.2,-1,171.89999,161.3,-1,-1,-1,174.39999,164.8,-1,160.39999,-1,-1,-1,-1,-1,145.89999,-1,-1,82.7,148.8,-1,-1,-1,140.5,-1,158.7,150.3,178.60001,165.2,149.3,152.39999,157.3,174.2,-1,-1,180.75101,140.89999,155.39999,161.10001,-1,-1,-1,-1,-1,153.3,150.60001,162.5,143,155.2,142.8,133.89999,161.10001,149.321,151.35699,161.58501}
        };
        return d;
    }
}
