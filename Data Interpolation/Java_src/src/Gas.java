/* Ozone value interpolation using wind speed and direction.
 *
 * Author: John Naruk (john.naruk@gmail.com)
 * Modified By: Sushil Joshi (sjoshi4@mail.uh.edu)
 */
package LatLongInterpolation_testing;

import java.util.Iterator;
import java.io.*;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Stack;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.awt.image.WritableRaster;

public class Gas
{
    public static void printArray(int[] array)
    {
        for(int x:array)
        System.out.print(x+"\t");
        System.out.println();
    }

    public static void printArray(double[][] array)
    {
        for(double[] v:array)
        {
            for(double x:v)System.out.print(x+"\t");
            System.out.println();
        }
        System.out.println();
    }

    public static void printArray(int[][] array)
    {
        for (int[] v:array)
        {
            for(int x:v) System.out.print(x+"\t");
            System.out.println();

        }
        System.out.println();

    }

    public static void printArray(double[] array)
    {
        for (double x:array)
            System.out.print(x + "\t");
        System.out.println();
    }

    /**
     * Gets the inner angle between two vectors in rectangular coordinates.
     * @param v1 The first vector.
     * @param v2 The second vector.
     * @return The angle between the vectors
     */
    public static double getAngle(double[] v1,double[] v2)
    {
        double a1 = Math.atan2(v1[0],v1[1]);
        double a2 = Math.atan2(v2[0],v2[1]);
        double a = Math.abs(a1-a2);
        return Math.min(a,Math.PI*2 - a);
    }

    /**
     * Calculates the slope of a regression line for values in an array and converts this to a multiplier
     * @param array The array of points to get the slope of
     * @return The slope multiplier for the array
     */
    public static double slope(double[] array)
    {
        double length = array.length;
        double start = -6/((length+1)*(length));
        double difference = -2*start/(length-1);
        double slope = 0;
        double total = 0;
        for(int i=0;i<length;i++)
        {
            if(array[i]>0)
            {
                slope += array[i]*(start+difference*i);
                total += array[i];
            }
        }
        if(total==0)
        {return 1;}
        return slope/total+1;
    }

    //CONSTANTS
    /**The number of surrounding points included in the approximation.*/
    private final int INCLUDED_POINTS = 18;
    /**The number of points retained in the trail, not including the current point.*/
    private final int TRAIL_POINTS = 6;
    /**The conversion from time between measurements to distance for the weighted average. Units of km/cycle.*/
    private final double TIME_DISTANCE = 3;
    /**Adding a distance to the time component for all points to smooth the contour plot assuming some values are not exact.*/
    private final double PRE_DISTANCE = 1;
    /**The conversion from distance in km to latitude and longitude angles in degrees. Units of degrees/km.*/
    private final double ANGLE_DISTANCE = .02822139369;
    /**The number of hours per cycle (less than one) to convert wind speed to movement during the cycle. Units of hours/cycle*/
    private final double TIME_PERIOD = 5.0/60.0;

    private final int REGION_DONE = 10000000;    // To mark that a particular region is already processed.. Use a high value for this
    
    // To mark valleys as largest or not. These values are to be added to contour list along with
    // latitude and longitude values. So, these values are picked far away from the range
    // of [-180, 180] degrees.
    private final double LARGEST_VALLEY_TRUE = 500.0;
    private final double LARGEST_VALLEY_FALSE = 1000.0;

    /* Direction flags for region calculation */
    private final int DIRECTION_RIGHT = 0;
    private final int DIRECTION_DOWN = 1;
    private final int DIRECTION_LEFT = 2;
    private final int DIRECTION_UP = 3;

    /* Debug image print turn on or off */
    private boolean writeDebugImages = false;
    
    /** Normal for each algorithmic direction during contour calculation. e.g. during
     * DIRECTION_RIGHT, normal is upwards i.e. towards neighbor currentX, currentY-1.
     * diag and backward have similar meanings corresponding to current point.
     **/
    double [][] normal = new double[4][2];
    double [][] diag = new double[4][2];
    double [][] backward = new double[4][2];

    //variables
    /**The number of stations in the approximation.*/
    public int stations=0;
    /**The coordinates for all the stations.*/
    public double[][] coordinates=new double[1][2];
    /**A three dimensional set of coordinates adjusted for wind with the third dimension being time.*/
    public double[][][] windcoordinates;
    /**The minimum x values of all stations.  This is initialized with a high value so the first value added overwrites it.*/
    public double latmin = Math.pow(10,1000);
    /**The maximum x values of all stations.  This is initialized with a low value so the first value added overwrites it.*/
    public double latmax = -Math.pow(10,1000);
    /**The minimum y values of all stations.  This is initialized with a high value so the first value added overwrites it.*/
    public double lonmin = Math.pow(10,1000);
    /**The maximum y values of all stations.  This is initialized with a low value so the first value added overwrites it.*/
    public double lonmax = -Math.pow(10,1000);
    /** Maximum and minimum values of the grid lat/lng that we finaly use during grid generation **/
    public double gridLatMin, gridLongMin;
    /**Stores whether the system has all values added.  This prevents ozone values from being added before all stations are added.*/
    public boolean validated=false;
    /**Stores if the value file has been set to prevent accessing values that do not exist.*/
    public boolean valueFileSet=false;
    /**Stores if the wind system has been set to prevent loading ozone values without it being set.*/
    public boolean windSet=false;
    /**The scanner used to bring in ozone values from the file.*/
    private DataScanner ozoneValues;
    /**The wind system used to adjust the coordinates for past data based on wind.*/
    public Wind wind;
    /**Stores a set of unadjusted ozone values for the approximation.*/
    public double[][] values1;
    /**Stores a set of ozone values adjusted for average rate of change for use in the approximation.*/
    public double[][] values2;
    /**Stores the distance from one station the the nearest six stations to give a higher weight to stations that are closer together*/
    public double[][] densityWeight;

    /**
     * Creates a new Ozone approximation system.
     * It creates the object and initializes some of the constants.
     */
    Gas()
    {
        normal[DIRECTION_RIGHT][0] = -1.0; normal[DIRECTION_RIGHT][1] = 0.0;
        normal[DIRECTION_DOWN][0] = 0.0; normal[DIRECTION_DOWN][1] = 1.0;
        normal[DIRECTION_LEFT][0] = 1.0; normal[DIRECTION_LEFT][1] = 0.0;
        normal[DIRECTION_UP][0] = 0.0; normal[DIRECTION_UP][1] = -1.0;
        
        diag[DIRECTION_RIGHT][0] = -2.0; diag[DIRECTION_RIGHT][1] = -1.0;
        diag[DIRECTION_DOWN][0] = -1.0; diag[DIRECTION_DOWN][1] = 2.0;
        diag[DIRECTION_LEFT][0] = 2.0; diag[DIRECTION_LEFT][1] = 1.0;
        diag[DIRECTION_UP][0] = 1.0; diag[DIRECTION_UP][1] = -2.0;
        
        backward[DIRECTION_RIGHT][0] = 0.0; backward[DIRECTION_RIGHT][1] = -1.0;
        backward[DIRECTION_DOWN][0] = -1.0; backward[DIRECTION_DOWN][1] = 0.0;
        backward[DIRECTION_LEFT][0] = 0.0; backward[DIRECTION_LEFT][1] = 1.0;
        backward[DIRECTION_UP][0] = 1.0; backward[DIRECTION_UP][1] = 0.0;
        
        writeDebugImages = true;
    }

    /**
     * Adds a new Ozone station
     * @param x The x coordinate of the station.
     * @param y The y coordinate of the station.
     */
    public void newStation(double lat,double lon)
    {
        if(!validated)
        {
            //Increments the array length
            double[][] oldcoordinates = coordinates.clone();
            coordinates = new double[stations+1][2];
            System.arraycopy(oldcoordinates,0,coordinates,0,stations);
            //Stores the location of the new station
            coordinates[stations][0]=lat;
            coordinates[stations][1]=lon;
            //Resets the maximum and minimum values for station locations
            latmin = Math.min(latmin,lat);
            latmax = Math.max(latmax,lat);
            lonmin = Math.min(lonmin,lon);
            lonmax = Math.max(lonmax,lon);
            stations++;
        }
    }

    /**
     * Loads a set of coordinates for ozone stations from given station coordinates.
     * @param stationCoordinates array of station coordinates
     *
     */
    public void loadStations(double[][] stationCoordinates)
    {
        if(!validated)
        {
            DataScanner inCoordinates = new DataScanner(stationCoordinates);
            while(true)//Placing the breakout condition after each value is added is the most efficent way to run this
            {
                double lat;
                double lon;
                //gets the x and y coordinates if in the file and breaks if no more numbers are in the file
                if(inCoordinates.hasNextDouble())
                {lat = inCoordinates.nextDouble();}
                else
                {return;}
                if(inCoordinates.hasNextDouble())
                {lon = inCoordinates.nextDouble();}
                else
                {return;}
                newStation(lat,lon);
                inCoordinates.nextLine();
            }
        }
    }

    /**
     * Initializes arrays with the correct sizes and starting values.
     * Stations cannot be added or removed after the system is validated.
     * Values cannot be added or approximated until the system is validated.
     * The Wind system or value files can be reset at any time.
     */
    public void validate()
    {
        windcoordinates = new double[TRAIL_POINTS][stations][3];
        values1 = new double[TRAIL_POINTS][stations];
        values2 = new double[TRAIL_POINTS][stations];
        densityWeight = new double[TRAIL_POINTS][stations];
        for(int i=0;i<TRAIL_POINTS;i++)
        {
            for(int j=0;j<stations;j++)
            {
                windcoordinates[i][j][0] = coordinates[j][0];
                windcoordinates[i][j][1] = coordinates[j][1];
                windcoordinates[i][j][2] = (PRE_DISTANCE+i*TIME_DISTANCE)*ANGLE_DISTANCE;
            }
        }
        validated=true;
    }

    /**
     * Sets the wind system to be used in conjunction with the ozone system.
     * This wind system must be created and have the new values added separately to the wind system before each ozone approximation.
     * @param wind The wind system for the ozone approximation
     */
    public void setWind(Wind wind)
    {
        this.wind=wind;
        windSet=true;
    }

    /**
     * setValueFile
     *
     * Loads a set of ozone values for ozone stations from given data source.
     * @param ozValues set of data points for each station, how many TRAIL_POINTS to be used
     * depends on the amount of data available here.
     *
     */
    public void setValueSource(double[][] ozValues)
    {
        ozoneValues = new DataScanner(ozValues);
        valueFileSet=true;
    }


    /**
     * Loads the next set of values from the value file and stores the in values1.
     * Calculates wind adjusted coordinates based on the wind system.  New values for the wind system should be added before adding new values to the ozone system.
     * Adjusts the ozone values based on slope and stores the adjusted values in values2
     * @param values the number of value sets to skip
     * @throws FileNotFoundException
     * @throws Exception
     */
    public void skipTo(int values) throws FileNotFoundException
    {
        for(int n=0;n<values-TRAIL_POINTS;n++)
        {
            for(int i=0;i<stations && ozoneValues.hasNextDouble();i++)
                values1[0][i]=ozoneValues.nextDouble();
            ozoneValues.nextLine();
            wind.loadNextValues();
        }
        for(int i=Math.max(values-TRAIL_POINTS,0);i<values;i++)
            loadNextValues();
    }

    public void loadAvailableValues()
    {
        for (int i=0; i<ozoneValues.dataLength; i++)
            loadNextValues();
    }

    /**
     * Loads the next set of values from the value file and stores the in values1.
     * Calculates wind adjusted coordinates based on the wind system.  New values for the wind system should be added before adding new values to the ozone system.
     * Adjusts the ozone values based on slope and stores the adjusted values in values2
     * @throws FileNotFoundException
     * @throws Exception
     */
    public void loadNextValues()
    {
        //blocks loading of values if the system is not validated
        if(validated && valueFileSet && windSet)
        {
            wind.loadNextValues();
            //moves the old values in each array by one time step
            for(int i=TRAIL_POINTS-1;i>0;i--)
            {
                for(int j=0;j<stations;j++)
                {
                    values1[i][j]=values1[i-1][j];
                    values2[i][j]=values2[i-1][j];
                }
            }
            //adds the new values to the array at the current time
            for(int i=0;i<stations && ozoneValues.hasNextDouble();i++)
            {
                values1[0][i]=ozoneValues.nextDouble();
                values2[0][i]=values1[0][i];
            }
            ozoneValues.nextLine();
            //adjusts the values based on the slope and stores them as values2
            double slope=0;
            for(int i=0;i<stations;i++)
            {
                double[] valuest=new double[TRAIL_POINTS];
                for(int j=0;j<TRAIL_POINTS;j++)
                {valuest[j]=values1[j][i];}
                slope+=slope(valuest);
            }
            slope=slope/stations;
            for(int i=0;i<TRAIL_POINTS;i++)
            {
                for(int j=0;j<stations;j++)
                {
                    values2[i][j]=values2[i][j]*slope;
                }
            }
            //updates the coordinates based on the wind system
            for(int i=0;i<stations;i++)
            {
                for(int j=TRAIL_POINTS-1;j>=1;j--)
                {
                    wind.setLocation(windcoordinates[j-1][i][0],windcoordinates[j-1][i][1]);
                    windcoordinates[j][i][0] = windcoordinates[j-1][i][0] + TIME_PERIOD * wind.getWindX() * ANGLE_DISTANCE;
                    windcoordinates[j][i][1] = windcoordinates[j-1][i][1] + TIME_PERIOD * wind.getWindY() * ANGLE_DISTANCE;
                }
            }
            //determines the density weights for each point in the field based on the distance to the nearest six points.  This calculation must run through each point twice.
            for(int m=0;m<TRAIL_POINTS;m++)
            {
                for(int n=0;n<stations;n++)
                {
                    double[] distance = new double[INCLUDED_POINTS+2];
                    for(int i=0;i<distance.length;i++) distance[i]=-1;
                    //finds distance to the closest six points
                    for(int i=0;i<TRAIL_POINTS;i++)
                    {
                        for(int j=1;j<stations;j++)
                        {
                            double dist = Math.pow( Math.pow(windcoordinates[m][n][0]-windcoordinates[i][j][0],2) + Math.pow((windcoordinates[m][n][1]-windcoordinates[m][n][1])*Math.cos(windcoordinates[m][n][0]*Math.PI/180),2) , 0.5 );
                            //The list of indicies is kept in order of which is closest as they are added to this list or skipped if farther away
                            for(int k=INCLUDED_POINTS;k>=0 && (distance[k]==-1 || distance[k] > dist);k--)
                            {
                                distance[k+1]=distance[k];
                                distance[k]=dist;
                            }
                        }
                    }
                    for(int i=0;i<INCLUDED_POINTS;i++) densityWeight[m][n]+=distance[i];
                }
            }
        }
    }

    /**
     * Loads the next set of values from the value file and stores the in values1.
     * Calculates wind adjusted coordinates based on the wind system.  New values for the wind system should be added before adding new values to the ozone system.
     * Adjusts the ozone values based on slope and stores the adjusted values in values2
     * @param newValues The next array of values
     */
    public void nextValues(double[] newValues)
    {
        if(validated)
        {
            //moves the old values in each array
            for(int i=TRAIL_POINTS-1;i>0;i--)
            {
                for(int j=0;j<stations;j++)
                {
                    values1[i-1][j]=values1[i][j];
                    values2[i-1][j]=values2[i][j];
                }
            }
            //adds the new values to the array
            for(int i=0;i<stations;i++)
            {
                values1[0][i]=newValues[i];
                values2[0][i]=values1[0][i];
            }
            //adjusts the values based on the slope
            double slope=0;
            for(int i=0;i<stations;i++)
            {
                double[] valuest=new double[TRAIL_POINTS];
                for(int j=0;j<TRAIL_POINTS;j++)
                {valuest[j]=values1[j][i];}
                slope+=slope(valuest);
            }
            slope=slope/stations;
            for(int i=0;i<TRAIL_POINTS;i++)
            {
                for(int j=0;j<stations;j++)
                {
                    values2[i][j]=values2[i][j]*slope;
                }
            }
            //updates the coordinates based on the wind system
            for(int i=0;i<stations;i++)
            {
                for(int j=TRAIL_POINTS-1;j>=1;j--)
                {
                    wind.setLocation(windcoordinates[j-1][i][0],windcoordinates[j-1][i][1]);
                    windcoordinates[j][i][0] = windcoordinates[j-1][i][0] + TIME_PERIOD * wind.getWindX() * ANGLE_DISTANCE;
                    windcoordinates[j][i][1] = windcoordinates[j-1][i][1] + TIME_PERIOD * wind.getWindY() * ANGLE_DISTANCE;
                }
            }
        }
    }

    /**
     * Gives the ozone concentration at the specified location based on the models.
     * All calculations done in this method must be repeated for each estimation point at each time interval because the wind adjusted coordinates change at each time interval.
     * @param x The x coordinate of the location
     * @param y The y coordinate of the location
     * @return The ozone concentration at the location
     */
    public double getValue(double lat,double lon)
    {
        //Calculates the distances between the point of approximation and all known points
        double[][] distanceWeight = new double[TRAIL_POINTS][stations];
        for(int j=0;j<stations;j++)
        {
            //if the pre distance is set to zero and the exact location of a valid station is called, this will give that value.
            if(PRE_DISTANCE==0 && windcoordinates[0][j][0]==lat && windcoordinates[0][j][1]==lon && values2[0][j]>0)
                return values2[0][j];
            for(int i=0;i<TRAIL_POINTS;i++)
            {
                //points for which the station is not giving a value can be given as -1 so the distance weight will be taken as 0, effectively eliminating the point from calculations
                if(values2[i][j]>0)
                    distanceWeight[i][j] = densityWeight[i][j]/( Math.pow(windcoordinates[i][j][0]-lat,2) + Math.pow((windcoordinates[i][j][1]-lon)*Math.cos(lat*Math.PI/180),2) + Math.pow(windcoordinates[i][j][2],2) );
                else
                    distanceWeight[i][j] = 0;
            }
        }
        //Creates lists for the indicies of the points to include in further calculations based on which are closest including the time distance for wind points
        int[] iIndex = new int[INCLUDED_POINTS+2];
        int[] jIndex = new int[INCLUDED_POINTS+2];
        for(int i=0;i<iIndex.length;i++)
        {
            iIndex[i]=-1;
            jIndex[i]=-1;
        }
        for(int i=0;i<TRAIL_POINTS;i++)
        {
            for(int j=1;j<stations;j++)
            {
                //The list of indicies is kept in order of which is closest as they are added to this list or skipped if farther away
                for(int k=INCLUDED_POINTS;k>=0 && (iIndex[k]==-1 || jIndex[k]==-1 || distanceWeight[i][j] > distanceWeight[iIndex[k]][jIndex[k]]);k--)
                {
                    iIndex[k+1]=iIndex[k];
                    jIndex[k+1]=jIndex[k];
                    iIndex[k]=i;
                    jIndex[k]=j;
                }
            }
        }
        //applies the distance and density weights to produce the final ozone value
        //density weights are calculated with the wind coordinates when the points are loaded
        //slope is already calculated for the values when they are loaded so it IS done once for each time period instead of for each ozone approximation
        //distance weight is already squared when first calculated
        double weightTotal = 0;
        double ozoneTotal = 0;
        for(int i=0;i<=INCLUDED_POINTS;i++)
        {
            double weight = (distanceWeight[iIndex[i]][jIndex[i]] - distanceWeight[iIndex[INCLUDED_POINTS]][jIndex[INCLUDED_POINTS]]);
//            System.out.println(iIndex[i]+"\t"+jIndex[i]+"\t"+densityWeight[iIndex[i]][jIndex[i]]+"\t"+distanceWeight[iIndex[i]][jIndex[i]]+"\t"+weight);
            ozoneTotal += values2[iIndex[i]][jIndex[i]] * weight;
            weightTotal += weight;
        }
        double ozoneValue = ozoneTotal/weightTotal;
        return ozoneValue;
    }

    /**
     *  getGrid
     *
     *  @param step Step size for generating the grid
     *
     */
    public double [][] getGrid(double step) {
        double latmint = step*((int) (latmin/step));
        double latmaxt = step*((int) (latmax/step)+1);
        double lonmint = step*((int) (lonmin/step));
        double lonmaxt = step*((int) (lonmax/step)+1);
        double val, grid[][];

        gridLatMin = latmint;    // set the public variable
        gridLongMin = lonmint;    // set the public variable
        grid = new double[(int)((latmaxt-latmint+step)/step)][(int)((lonmaxt-lonmint+step)/step)]; // +step is necessary because following for loop does inclusive looping
        int i, j;
        i = j = 0;
        for(double lat=latmint;lat<=latmaxt;lat+=step)
        {
            j = 0;
            for(double lon=lonmint;lon<=lonmaxt;lon+=step)
            {
                val = getValue(lat, lon);
                grid[i][j] = val;
                j++;
            }
            i++;
        }
        return grid;
    }

    /*
     * setLatLngExtent
     *
     * Set the lat/lng extent of the grid to values supplied by configuration. This overrides the
     * extent calculated from available stations.
     *
     * @param gridExtent Hashmap of latmin, latmax, lonmin, lonmax
     */
    public void setLatLngExtent(HashMap<String, Double> gridExtent) {
        latmin = gridExtent.get("latmin");
        latmax = gridExtent.get("latmax");
        lonmin = gridExtent.get("longmin");
        lonmax = gridExtent.get("longmax");
    }

    public void setWriteDebugImages(boolean debug) {
        writeDebugImages = debug;
    }
    
    /*
     * getContours
     *
     * @param step Size of each grid cell.
     * @param discreteBand Hashmap of ozone bands for discretizing each region of contours
     * @return List of contour polygons for data supplied. The last item is always the label id of each contour in the same
     *             sequence as contours are added to the contourList
     */
    public List<List<double []>> getContours(double step, HashMap<Integer, Double> discreteBand) throws IOException
    {
        List<List<double []>> contourList = new ArrayList<List<double []>>();
        List<List<double []>> ret;
        List<double []> contourIndices = new ArrayList<double []>();
        int xSize, ySize;
        double latmint = step*((int) (latmin/step));
        double latmaxt = step*((int) (latmax/step)+1);
        double lonmint = step*((int) (lonmin/step));
        double lonmaxt = step*((int) (lonmax/step)+1);
        ySize = (int) ((latmaxt - latmint) / step);
        xSize = (int) ((lonmaxt - lonmint) / step);
        // Get total band count and label id for each band
        int bandCount = discreteBand.size();
        int[] label = new int[bandCount];
        double[] limits = new double[bandCount];

        // initialize k frames, one frame for each of the discreteBand
        // dimensions are k, x, y.. This effectively creates one frame for each band of ozone values.
        int[][][] kRegions = initializeKFrames(discreteBand, label, limits, step);
        debugWriteKFramesImage(kRegions, bandCount, xSize, ySize);
        
        long startTime = System.currentTimeMillis();
        // for each frame, get contours and add contour to list
        for (int i=0; i<bandCount; i++) {
            ret = getFrameContours(kRegions[i], label[i], step);

            // each frame can have multiple contours, considering multiple islands
            for (int j=0; j<ret.size(); j++) {
                contourList.add(ret.get(j));
                contourIndices.add(new double[]{label[i]});
                System.out.println("Adding label: " + label[i] + " contour size: " + ret.get(j).size());
            }
        }
        
        // start for valleys from highest label. This calculates the negative of each frame.
        // Thus at i th iteration, i+1 th iteration will always have negative. So, looking up
        // at the kRegions at i+1 th label is appropriate to find whether i th labelled
        // valley is largest or not.
        for (int i=bandCount-1; i>0; i--) {
            negative(kRegions[i], REGION_DONE, label[i], xSize, ySize);
            ret = getFrameContours(kRegions[i], label[i], step, true);
            int li = ret.size() - 1; // last index
            List<double []> seedList = ret.get(li);
            ret.remove(li);
            int x, y;
            
            // at this point seedList.size and ret.size have to be same.. Just put a quick check for debugging..
            if (seedList.size() != ret.size()) {
                System.out.println("seedlist:ret sizes " + seedList.size() + ":" + ret.size());
            }
            
            for (int j=0; j<ret.size(); j++) {
                x = (int)seedList.get(j)[0];
                y = (int)seedList.get(j)[1];
                if ((i == bandCount-1) || (i < bandCount - 1 && x < xSize && y < ySize && kRegions[i+1][y][x] == REGION_DONE)) {
                    ret.get(j).add(new double[] {LARGEST_VALLEY_TRUE, LARGEST_VALLEY_TRUE});
                    //System.out.println("largest");
                } else {
                    ret.get(j).add(new double[] {LARGEST_VALLEY_FALSE, LARGEST_VALLEY_FALSE});
                    //System.out.println("not largest");
                }
                contourList.add(ret.get(j));
                contourIndices.add(new double[]{-label[i]});
                System.out.println("Adding valley for label: " + label[i] + " contour size:" + ret.get(j).size());
            }
        }
        System.out.println("Time taken for finding contours: " + (System.currentTimeMillis() - startTime));
        // add contour indices to contourList
        contourList.add(contourIndices);

        // return the result
        return contourList;
    }

    private int[][][] initializeKFrames(HashMap<Integer, Double> discreteBand, int[] label, double[] limits, double step) {
        int xSize, ySize;
        double latmint = step*((int) (latmin/step));
        double latmaxt = step*((int) (latmax/step)+1);
        double lonmint = step*((int) (lonmin/step));
        double lonmaxt = step*((int) (lonmax/step)+1);
        int bandCount = discreteBand.size();
        double val;
        ySize = (int) ((latmaxt - latmint) / step);
        xSize = (int) ((lonmaxt - lonmint) / step);
        int[][][] kFrames = new int[bandCount][ySize][xSize];
        double [] imgData = new double[xSize * ySize];
        
        Iterator<Entry<Integer, Double>> itr = discreteBand.entrySet().iterator();
        int iteratorPos=0;
        while (itr.hasNext()) {
            Map.Entry<Integer, Double> kv = itr.next();
            label[iteratorPos] = kv.getKey();
            limits[iteratorPos] = kv.getValue();
            iteratorPos++;
        }

        // since HashMap does not preserve sequence, sort the above two arrays based on limits.
        // Use simple bubble sort as we are not expecting size of this to be too large
        for (int pass=0; pass<limits.length; pass++) {
            for (int pos=0; pos<limits.length - 1; pos++) {
                if (limits[pos] > limits[pos+1]) {
                    int tempI = label[pos];
                    double tempD = limits[pos];
                    label[pos] = label[pos+1];
                    limits[pos] = limits[pos+1];
                    label[pos+1] = tempI;
                    limits[pos+1] = tempD;
                }
            }
        }

        int x = 0;
        int y = 0;
        for(double lat=latmint;lat<=latmaxt;lat+=step)
        {
            x = 0; // re-initialize x
            for(double lon=lonmint;lon<=lonmaxt;lon+=step)
            {
                val = getValue(lat, lon);
                if (x >= xSize || y>=ySize) {
                    continue;
                }
                // 0 - limits[1] => label[1], limits[1] - limits[2] => label[2] and so on
                double lower = 0;
                for (int i=0; i<bandCount; i++) {
                    if (val > lower) {
                        kFrames[i][y][x] = label[i];
                    } else {
                        kFrames[i][y][x] = REGION_DONE;
                    }
                    lower = limits[i];
                }

                imgData[y * xSize + x ] = label[bandCount - 1];
                for (int i=0; i<bandCount; i++) {
                    if (val <= limits[i]) {
                        imgData[y * xSize + x ] = label[i];
                        break;
                    }
                }
                x++;
            }
            y++;
        }

        debugWriteImageData(imgData, xSize, ySize, "/tmp/binaryout.png");
        return kFrames;
    }

    private List<List<double []>> getFrameContours(int[][] region, int regionId, double step) {
        return getFrameContours(region, regionId, step, false);
    }
    
    private List<List<double []>> getFrameContours(int[][] region, int regionId, double step, boolean getSeedList) {
        List<List<double []>> ret = new ArrayList<List<double []>>();
        int xSize, ySize;
        double latmint = step*((int) (latmin/step));
        double latmaxt = step*((int) (latmax/step)+1);
        double lonmint = step*((int) (lonmin/step));
        double lonmaxt = step*((int) (lonmax/step)+1);
        ySize = (int) ((latmaxt - latmint) / step);
        xSize = (int) ((lonmaxt - lonmint) / step);
        int [][] done = new int[ySize][xSize];

        boolean loopDetected;
        int [] seed = new int[]{-1,-1};
        List<double []> seedListBackup = new ArrayList<double []>(); // initialized as double so as to be returned along with contour
        int [] currentPoint = new int[]{0, 0};
        int currentRegionId = regionId;
        int currentDirection = DIRECTION_RIGHT;
        int startX, startY, sstartX, sstartY;
        String breadCrumbKey;
        int x = 0;
        int y = 0;

        // Initialize seed by raster scanning the region array
        // Important: For initialization of seed, region[][] array is scanned but inside the while loop, done[][] array is also inspected
        for (int i=0; i<ySize; i++) {
            // shooting the ray along x-axis from left to right for each row
            for (int j=0; j<xSize; j++) {
                if (region[i][j] == regionId) {
                    seed[0] = j;
                    seed[1] = i;
                    break;
                }
            }
            // if seed found, break the search
            if (seed[0] >= 0 && seed[1] >= 0) {
                break;
            }
        }

        while (seed[0] >= 0) {
            seedListBackup.add(new double[]{seed[0], seed[1]});
            List<double []> contour = new ArrayList<double []>();
            HashMap<String, Integer> breadCrumb = new HashMap<String, Integer>();
            currentPoint[0] = seed[0]; currentPoint[1] = seed[1];
            // just find the direction to traverse
            x = startX = sstartX = currentPoint[0];
            y = startY = sstartY = currentPoint[1];
            currentDirection = DIRECTION_RIGHT; // always try right direction as start direction (for clockwise)
            Stack<int[]> neighborHood = new Stack<int[]>(); // for pushing the currently identified contour points to mark as REGION_DONE once contour is identified.
            while(currentPoint[0] >= 0 && currentPoint[1] >= 0) {
                x = currentPoint[0];
                y = currentPoint[1];
                // if currentPoint forms a loop in the contour, break the loop; we have found one contour

                loopDetected = false; //(x == startX) && (y == startY) || (x == sstartX) && (y == sstartY);

                breadCrumbKey = x+"_"+y+"_"+currentDirection;
                if (breadCrumb.containsKey(breadCrumbKey)) {
                    loopDetected = true;
                }

                if (contour.size() > 0 && loopDetected && done[y][x] == REGION_DONE) {
                    // Before breaking this loop, mark done for all the points bounded by
                    // contour identified so far. This can be done by traversing the 8-neighborhood of
                    // all the points lying along the contour lines
                    int[] item;
                    while (!neighborHood.isEmpty()) {
                        item = neighborHood.pop();
                        x = item[0];
                        y = item[1];
                        // (level - 1) neighbors
                        if (y-1 >=0 && region[y-1][x] == currentRegionId && done[y-1][x] != REGION_DONE) {
                            neighborHood.push(new int[]{x, y-1});
                            done[y-1][x] = REGION_DONE;
                        }
                        if (y-1 >=0 && x-1 >= 0 && region[y-1][x-1] == currentRegionId && done[y-1][x-1] != REGION_DONE) {
                            neighborHood.push(new int[]{x-1, y-1});
                            done[y-1][x-1] = REGION_DONE;
                        }
                        if (y-1 >=0 && x+1 < xSize && region[y-1][x+1] == currentRegionId && done[y-1][x+1] != REGION_DONE) {
                            neighborHood.push(new int[]{x+1, y-1});
                            done[y-1][x+1] = REGION_DONE;
                        }

                        // (level) neighbors
                        if (x-1 >=0 && region[y][x-1] == currentRegionId && done[y][x-1] != REGION_DONE) {
                            neighborHood.push(new int[]{x-1, y});
                            done[y][x-1] = REGION_DONE;
                        }
                        if (x+1 < xSize && region[y][x+1] == currentRegionId && done[y][x+1] != REGION_DONE) {
                            neighborHood.push(new int[]{x+1, y});
                            done[y][x+1] = REGION_DONE;
                        }

                        // (level + 1) neighbors
                        if (y+1 < ySize && region[y+1][x] == currentRegionId && done[y+1][x] != REGION_DONE){
                            neighborHood.push(new int[]{x, y+1});
                            done[y+1][x] = REGION_DONE;
                        }
                        if (y+1 < ySize && x-1 >= 0 && region[y+1][x-1] == currentRegionId && done[y+1][x-1] != REGION_DONE){
                            neighborHood.push(new int[]{x-1, y+1});
                            done[y+1][x-1] = REGION_DONE;
                        }
                        if (y+1 < ySize && x+1 < xSize && region[y+1][x+1] == currentRegionId && done[y+1][x+1] != REGION_DONE){
                            neighborHood.push(new int[]{x+1, y+1});
                            done[y+1][x+1] = REGION_DONE;
                        }
                    }
                    break;
                }

                done[y][x] = REGION_DONE;
                neighborHood.push(new int[]{x, y});
                breadCrumb.put(breadCrumbKey, 1);

                // find next point in the same region that is along the boundary of the region
                switch(currentDirection) {
                case DIRECTION_RIGHT:
                    if (x-1 >= 0 && y-1 >= 0 && done[y][x] != REGION_DONE && region[y-1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_UP;
                    } else if (y-1 >= 0 && region[y-1][x] == currentRegionId) {
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_UP;
                    } else if (x+1 < xSize && y-1 >= 0 && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                    } else if (x+1 < xSize && region[y][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                    } else if (x+1 < xSize && y+1 < ySize && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                    } else {
                        if (x+1 < xSize && seed[0] < 0 && done[y][x+1] != REGION_DONE) {
                            // initialize seed for the next region
                            seed[0] = x+1;
                            seed[1] = y;
                        }
                        currentDirection = DIRECTION_DOWN;
                    }
                    break;
                case DIRECTION_DOWN:
                    if (x+1 < xSize && y-1 >= 0  && done[y][x] != REGION_DONE && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_RIGHT;
                    } else if (x+1 < xSize && region[y][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentDirection = DIRECTION_RIGHT;
                    } else if (x+1 < xSize && y+1 < ySize && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                    } else if (y+1 < ySize && region[y+1][x] == currentRegionId) {
                        currentPoint[1] += 1;
                    } else if (y+1 < ySize && x-1 >= 0 && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                    } else {
                        if (y+1 < ySize && seed[0] < 0 && done[y+1][x] != REGION_DONE) {
                            seed[0] = x;
                            seed[1] = y+1;
                        }
                        currentDirection = DIRECTION_LEFT;
                    }
                    break;
                case DIRECTION_LEFT:
                    if (x+1 < xSize && y+1 < ySize && done[y][x] != REGION_DONE && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_DOWN;
                    } else if (y+1 < ySize && region[y+1][x] == currentRegionId) {
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_DOWN;
                    } else if (x-1 >= 0 && y+1 < ySize && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                    } else if (x-1 >= 0 && region[y][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                    } else if (x-1 >= 0 && y-1 >= 0 && region[y-1][x-1] == currentRegionId){
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                    } else {
                        if (x-1 >= 0 && seed[0] < 0 && done[y][x-1] != REGION_DONE) {
                            seed[0] = x-1;
                            seed[1] = y;
                        }
                        currentDirection = DIRECTION_UP;
                    }
                    break;
                case DIRECTION_UP:
                    if (x-1 >= 0 && y+1 < ySize && done[y][x] != REGION_DONE && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_LEFT;
                    } else if (x-1 >= 0 && region[y][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentDirection = DIRECTION_LEFT;
                    } else if (x-1 >= 0 && y-1 >= 0 && region[y-1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                    } else if (y-1 >= 0 && region[y-1][x] == currentRegionId) {
                        currentPoint[1] -= 1;
                    } else if (x+1 < xSize && y-1 >= 0 && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                    } else {
                        if (y-1 >= 0 && seed[0] < 0 && done[y-1][x] != REGION_DONE) {
                            seed[0] = x;
                            seed[1] = y-1;
                        }
                        currentDirection = DIRECTION_RIGHT;
                    }
                    break;
                }

                contour.add(new double[]{latmint + y*step, lonmint + x*step});
            }
            ret.add(contour);

            // Try ray scanning again for other possible islands
            seed[0] = seed[1] = -1;
            for (int i=0; i<ySize; i++) {
                // shooting the ray along x-axis from left to right for each row
                for (int j=0; j<xSize; j++) {
                    if (region[i][j] == regionId && done[i][j] != REGION_DONE) {
                        seed[0] = j;
                        seed[1] = i;
                        break;
                    }
                    // if seed found, break the search
                    if (seed[0] >= 0 && seed[1] >= 0) {
                        break;
                    }
                }
            }
        }

        if (getSeedList) {
            ret.add(seedListBackup);
        }
        return ret;
    }

    private void floodFill(int[][] frame, int srcRegionId, int destRegionId, int seedX, int seedY, int xSize, int ySize) {
        // Before breaking this loop, mark done for all the points bounded by
        // contour identified so far. This can be done by traversing the 4-neighborhood of
        // startX and startY
        if (seedX <  0 || seedX >= xSize || seedY < 0 || seedY >= ySize || frame[seedY][seedX] == destRegionId) {
            // nothing to do
            return;
        }
        Stack<int[]> neighborHood = new Stack<int[]>();
        neighborHood.push(new int[]{seedX, seedY});
        int[] item;
        int x, y;
        while (!neighborHood.isEmpty()) {
            item = neighborHood.pop();
            x = item[0];
            y = item[1];
            // (level - 1) neighbors
            if (y-1 >=0 && frame[y-1][x] == srcRegionId) {
                neighborHood.push(new int[]{x, y-1});
                frame[y-1][x] = destRegionId;
            }
            if (y-1 >=0 && x-1 >= 0 && frame[y-1][x-1] == srcRegionId) {
                neighborHood.push(new int[]{x-1, y-1});
                frame[y-1][x-1] = destRegionId;
            }
            if (y-1 >=0 && x+1 < xSize && frame[y-1][x+1] == srcRegionId) {
                neighborHood.push(new int[]{x+1, y-1});
                frame[y-1][x+1] = destRegionId;
            }

            // (level) neighbors
            if (x-1 >=0 && frame[y][x-1] == srcRegionId) {
                neighborHood.push(new int[]{x-1, y});
                frame[y][x-1] = destRegionId;
            }
            if (x+1 < xSize && frame[y][x+1] == srcRegionId) {
                neighborHood.push(new int[]{x+1, y});
                frame[y][x+1] = destRegionId;
            }

            // (level + 1) neighbors
            if (y+1 < ySize && frame[y+1][x] == srcRegionId){
                neighborHood.push(new int[]{x, y+1});
                frame[y+1][x] = destRegionId;
            }
            if (y+1 < ySize && x-1 >= 0 && frame[y+1][x-1] == srcRegionId){
                neighborHood.push(new int[]{x-1, y+1});
                frame[y+1][x-1] = destRegionId;
            }
            if (y+1 < ySize && x+1 < xSize && frame[y+1][x+1] == srcRegionId){
                neighborHood.push(new int[]{x+1, y+1});
                frame[y+1][x+1] = destRegionId;
            }
        }  
    }
    
    private void negative(int[][] frame, int srcRegionId, int destRegionId, int xSize, int ySize) {
        for (int i=0; i<ySize; i++) {
            for (int j=0; j<xSize; j++) {
                if (frame[i][j] == srcRegionId) {
                    frame[i][j] = destRegionId;
                } else if (frame[i][j] == destRegionId) {
                    frame[i][j] = srcRegionId;
                }
            }
        }
        
        for (int i=0; i<xSize; i++) {
            // along top border
            floodFill(frame, destRegionId, REGION_DONE, i, 0, xSize, ySize);
            // along bottom border
            floodFill(frame, destRegionId, REGION_DONE, i, ySize-1, xSize, ySize);
        }
        
        for (int i=0; i<ySize; i++) {
            // along left border
            floodFill(frame, destRegionId, REGION_DONE, 0, i, xSize, ySize);
            // along right border
            floodFill(frame, destRegionId, REGION_DONE, xSize-1, i, xSize, ySize);
        }
    }
    
    private void debugWriteImageData(double[] imgData, int xSize, int ySize, String fileName) {
        // this flag can be turned off during production mode
        if (!writeDebugImages) {
            return;
        }
        
        BufferedImage bi = new BufferedImage(xSize, ySize, BufferedImage.TYPE_BYTE_GRAY);
        WritableRaster raster = (WritableRaster) bi.getData();
        raster.setPixels(0, 0, xSize, ySize, imgData);
        bi.setData(raster);
        File outputfile = new File(fileName);
        try {
            ImageIO.write(bi, "png", outputfile);
        } catch (IOException e) {
            System.out.println("Exception writing image output file");
        }
    }
    
    private void debugWriteKFramesImage(int[][][] kFrames, int bandCount, int xSize, int ySize) {
        if (!writeDebugImages) {
            return;
        }
        double [] imgData = new double[xSize * ySize];
        int maxLabel;
        /// write the largest of kFrames to imgData
        for (int i=0; i<ySize; i++) {
            for (int j=0; j<xSize; j++) {
                // find the largest out of kFrames
                maxLabel = kFrames[0][i][j];
                for (int k=0; k<bandCount; k++) {
                    if (kFrames[k][i][j] != REGION_DONE && kFrames[k][i][j] > maxLabel) {
                        maxLabel = kFrames[k][i][j];
                    }
                }
                imgData[i * xSize + j ] = maxLabel;
            }
        }
        debugWriteImageData(imgData, xSize, ySize, "/tmp/binaryoutk.png");
    }
    
    /**
     * Prints a coordinate grid to a csv file.
     * @param file The name of the file to print the values to.
     * @param step The step size for printing values
     * @throws IOException
     */
    public List<List<double []>> filePrintGrid(String file,double step, HashMap<Integer, Double> discreteBand) throws IOException
    {
        PrintWriter outFile = new PrintWriter(new BufferedWriter(new FileWriter(file)));
        double latmint = step*((int) (latmin/step));
        double latmaxt = step*((int) (latmax/step)+1);
        double lonmint = step*((int) (lonmin/step));
        double lonmaxt = step*((int) (lonmax/step)+1);
        double val;
        int bandCount = discreteBand.size();
        int[] label = new int[bandCount];
        double[] limits = new double[bandCount];
        Iterator<Entry<Integer, Double>> itr = discreteBand.entrySet().iterator();
        int iteratorPos=0;
        while (itr.hasNext()) {
            Map.Entry<Integer, Double> kv = itr.next();
            label[iteratorPos] = kv.getKey();
            limits[iteratorPos] = kv.getValue();
            iteratorPos++;
        }
        // since HashMap does not preserve sequence, sort the above two arrays based on limits.
        // Use simple bubble sort as we are not expecting size of this to be too large
        for (int pass=0; pass<limits.length; pass++) {
            for (int pos=0; pos<limits.length - 1; pos++) {
                if (limits[pos] > limits[pos+1]) {
                    int tempI = label[pos];
                    double tempD = limits[pos];
                    label[pos] = label[pos+1];
                    limits[pos] = limits[pos+1];
                    label[pos+1] = tempI;
                    limits[pos+1] = tempD;
                }
            }
        }

        int ySize, xSize;
        ySize = (int) ((latmaxt - latmint) / step);
        xSize = (int) ((lonmaxt - lonmint) / step);
        int [][] region = new int[ySize][xSize];
        int [][] done = new int[ySize][xSize];
        double [] imgData = new double[xSize * ySize];
        System.out.println("xSize: "+xSize+", ySize: "+ySize);

        int x = 0;
        int y = 0;
        for(double lat=latmint;lat<=latmaxt;lat+=step)
        {
            x = 0; // re-initialize x
            for(double lon=lonmint;lon<=lonmaxt;lon+=step)
            {
                val = getValue(lat, lon);
                outFile.println(lat+","+lon+","+val);
                // calculate the AQI index depending on aqiBase and divide the grid into regions
                // Half, Standard, OneHalf, Double, Triple, 5x of the Standard
                // ppb value represented by aqiBase
                if (x < xSize && y < ySize) {
                    region[y][x] = label[bandCount - 1];
                    imgData[y * xSize + x ] = label[bandCount - 1];
                    for (int i=0; i<bandCount; i++) {
                        if (val <= limits[i]) {
                            region[y][x] = label[i];
                            imgData[y * xSize + x ] = label[i];
                            break;
                        }
                    }
                }
                x++;
            }
            y++;
        }
        outFile.close();

        //printArray(region);
        //printArray(imgData);
        // Print region to gray scale image for visualization purpose
        BufferedImage bi = new BufferedImage(xSize, ySize, BufferedImage.TYPE_BYTE_GRAY);
        WritableRaster raster = (WritableRaster) bi.getData();
        raster.setPixels(0, 0, xSize, ySize, imgData);
        bi.setData(raster);
        File outputfile = new File(file + ".png");
        ImageIO.write(bi, "png", outputfile);

        // Find the contour lines by looking at region array
        // The seed point should always be the boundary of the next region. This can be ensured
        // by setting it only when boundary of a region is arrived.
        long contourStart = System.currentTimeMillis();

        List<List<double []>> ret = new ArrayList<List<double []>>();
        List<double []> contourIndices = new ArrayList<double []>();
        boolean loopDetected;
        int [] seed = new int[]{0,0};
        int [] currentPoint = new int[]{0, 0};
        int currentRegionId = region[0][0];
        int currentDirection = DIRECTION_RIGHT;
        int startX, startY, sstartX, sstartY, startDirection;
        double latHalfMargin=0.0, lonHalfMargin=0.0;
        double diagLatMargin=0.0, diagLonMargin=0.0;
        String breadCrumbKey;
        x = 0;
        y = 0;

        while (seed[0] >= 0) {
            System.out.println("Entered with seed at: " + seed[0] + ", " + seed[1]);
            List<double []> contour = new ArrayList<double []>();
            HashMap<String, Integer> breadCrumb = new HashMap<String, Integer>();
            currentPoint[0] = seed[0]; currentPoint[1] = seed[1];
            // just find the direction to traverse
            x = startX = sstartX = currentPoint[0];
            y = startY = sstartY = currentPoint[1];
            currentRegionId = region[y][x];
            currentDirection = DIRECTION_RIGHT;
            /*
            if (y-1 < 0 || region[y-1][x] != currentRegionId) {
                currentDirection = startDirection = DIRECTION_RIGHT;
            } else if (x+1 >= xSize || region[y][x+1] != currentRegionId) {
                currentDirection = startDirection = DIRECTION_DOWN;
            } else if (y+1 >= ySize || region[y+1][x] != currentRegionId) {
                currentDirection = startDirection = DIRECTION_LEFT;
            } else {
                currentDirection = startDirection = DIRECTION_UP;
            }
            */

            // Find the contour and mark the region as REGION_DONE
            int noChangeCount = 0;
            while(currentPoint[0] >= 0 && currentPoint[1] >= 0) {
                // debugDoneArrayImage to be used only in debug mode where checking the
                // done Array generated so far is done by line by line debug
                //debugDoneArrayImage(done, xSize, ySize);
                x = currentPoint[0];
                y = currentPoint[1];
                // if currentPoint forms a loop in the contour, break the loop; we have found
                // the contour for the current region.

                //loopDetected = (x == startX) && (y == startY) || (x == sstartX) && (y == sstartY);

                if (contour.size() == 1) {
                    // 0th index on contour is noted down on startX and startY
                    // 1th index is noted down on sstartX and sstartY. This is done so as to
                    // catch the rare cases when first point is never re-visited (probably due to direction in which the algo is traversing - not sure yet why this is happening for some cases)
                    sstartX = x;
                    sstartY = y;
                }

                breadCrumbKey = x+"_"+y+"_"+currentDirection;
                loopDetected = false;
                if (breadCrumb.containsKey(breadCrumbKey)) {
                    loopDetected = true;
                }

                if (contour.size() > 0 && loopDetected && done[y][x] == REGION_DONE) {
                    // Before breaking this loop, mark done for all the points bounded by
                    // contour identified so far. This can be done by traversing the 8-neighborhood of
                    // startX and startY
                    boolean topLeftDiag, topRightDiag, bottomLeftDiag, bottomRightDiag;
                    Stack<int[]> neighborHood = new Stack<int[]>();
                    neighborHood.push(new int[]{startX, startY});
                    int[] item;
                    while (!neighborHood.isEmpty()) {
                        item = neighborHood.pop();
                        x = item[0];
                        y = item[1];
                        // condition to include any of the diagonal neighbors for marking as done. This prevents crossing over the diagonal of contour line
                        topLeftDiag = (x-1 >= 0 && region[y][x-1] == currentRegionId) || (y-1 >= 0 && region[y-1][x] == currentRegionId);
                        topRightDiag = (x+1 < xSize && region[y][x+1] == currentRegionId) || (y-1 >= 0 && region[y-1][x] == currentRegionId);
                        bottomLeftDiag = (x-1 >= 0 && region[y][x-1] == currentRegionId) || (y+1 < ySize && region[y+1][x] == currentRegionId);
                        bottomRightDiag = (x+1 < xSize && region[y][x+1] == currentRegionId) || (y+1 < ySize && region[y+1][x] == currentRegionId);
                        // (level - 1) neighbors
                        if (y-1 >=0 && region[y-1][x] == currentRegionId && done[y-1][x] != REGION_DONE) {
                            neighborHood.push(new int[]{x, y-1});
                            done[y-1][x] = REGION_DONE;
                        }
                        if (topLeftDiag && y-1 >=0 && x-1 >= 0 && region[y-1][x-1] == currentRegionId && done[y-1][x-1] != REGION_DONE) {
                            neighborHood.push(new int[]{x-1, y-1});
                            done[y-1][x-1] = REGION_DONE;
                        }
                        if (topRightDiag && y-1 >=0 && x+1 < xSize && region[y-1][x+1] == currentRegionId && done[y-1][x+1] != REGION_DONE) {
                            neighborHood.push(new int[]{x+1, y-1});
                            done[y-1][x+1] = REGION_DONE;
                        }

                        // (level) neighbors
                        if (x-1 >=0 && region[y][x-1] == currentRegionId && done[y][x-1] != REGION_DONE) {
                            neighborHood.push(new int[]{x-1, y});
                            done[y][x-1] = REGION_DONE;
                        }
                        if (x+1 < xSize && region[y][x+1] == currentRegionId && done[y][x+1] != REGION_DONE) {
                            neighborHood.push(new int[]{x+1, y});
                            done[y][x+1] = REGION_DONE;
                        }

                        // (level + 1) neighbors
                        if (y+1 < ySize && region[y+1][x] == currentRegionId && done[y+1][x] != REGION_DONE){
                            neighborHood.push(new int[]{x, y+1});
                            done[y+1][x] = REGION_DONE;
                        }
                        if (bottomLeftDiag && y+1 < ySize && x-1 >= 0 && region[y+1][x-1] == currentRegionId && done[y+1][x-1] != REGION_DONE){
                            neighborHood.push(new int[]{x-1, y+1});
                            done[y+1][x-1] = REGION_DONE;
                        }
                        if (bottomRightDiag && y+1 < ySize && x+1 < xSize && region[y+1][x+1] == currentRegionId && done[y+1][x+1] != REGION_DONE){
                            neighborHood.push(new int[]{x+1, y+1});
                            done[y+1][x+1] = REGION_DONE;
                        }

                    }
                    break;
                }

                latHalfMargin = normal[currentDirection][0] * step/2;
                lonHalfMargin = normal[currentDirection][1] * step/2;
                diagLatMargin = diag[currentDirection][0] * step/2;
                diagLonMargin = diag[currentDirection][1] * step/2;
                done[y][x] = REGION_DONE;
                breadCrumb.put(breadCrumbKey, 1);

                // find next point in the same region that is along the boundary of the region
                boolean pipeDirectionChange = false;
                boolean currentPointNotChanged = false;
                switch(currentDirection) {
                case DIRECTION_RIGHT:
                    if (x-1 >= 0 && y-1 >= 0 && done[y][x] != REGION_DONE && region[y-1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_UP;
                        pipeDirectionChange = true;
                    } else if (y-1 >= 0 && region[y-1][x] == currentRegionId) {
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_UP;
                        pipeDirectionChange = true;
                    } else if (x+1 < xSize && y-1 >= 0 && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                    } else if (x+1 < xSize && region[y][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                    } else if (x+1 < xSize && y+1 < ySize && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                    } else {
                        if (x+1 < xSize && seed[0] < 0 && done[y][x+1] != REGION_DONE) {
                            // initialize seed for the next region
                            //seed[0] = x+1;
                            //seed[1] = y;
                        }
                        currentDirection = DIRECTION_DOWN;
                        currentPointNotChanged = true;
                    }
                    break;
                case DIRECTION_DOWN:
                    if (x+1 < xSize && y-1 >= 0  && done[y][x] != REGION_DONE && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                        currentDirection = DIRECTION_RIGHT;
                        pipeDirectionChange = true;
                    } else if (x+1 < xSize && region[y][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentDirection = DIRECTION_RIGHT;
                        pipeDirectionChange = true;
                    } else if (x+1 < xSize && y+1 < ySize && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                    } else if (y+1 < ySize && region[y+1][x] == currentRegionId) {
                        currentPoint[1] += 1;
                    } else if (y+1 < ySize && x-1 >= 0 && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                    } else {
                        if (y+1 < ySize && seed[0] < 0 && done[y+1][x] != REGION_DONE) {
                            //seed[0] = x;
                            //seed[1] = y+1;
                        }
                        currentDirection = DIRECTION_LEFT;
                        currentPointNotChanged = true;
                    }
                    break;
                case DIRECTION_LEFT:
                    if (x+1 < xSize && y+1 < ySize && done[y][x] != REGION_DONE && region[y+1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_DOWN;
                        pipeDirectionChange = true;
                    } else if (y+1 < ySize && region[y+1][x] == currentRegionId) {
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_DOWN;
                        pipeDirectionChange = true;
                    } else if (x-1 >= 0 && y+1 < ySize && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                    } else if (x-1 >= 0 && region[y][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                    } else if (x-1 >= 0 && y-1 >= 0 && region[y-1][x-1] == currentRegionId){
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                    } else {
                        if (x-1 >= 0 && seed[0] < 0 && done[y][x-1] != REGION_DONE) {
                            //seed[0] = x-1;
                            //seed[1] = y;
                        }
                        currentDirection = DIRECTION_UP;
                        currentPointNotChanged = true;
                    }
                    break;
                case DIRECTION_UP:
                    if (x-1 >= 0 && y+1 < ySize && done[y][x] != REGION_DONE && region[y+1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] += 1;
                        currentDirection = DIRECTION_LEFT;
                        pipeDirectionChange = true;
                    } else if (x-1 >= 0 && region[y][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentDirection = DIRECTION_LEFT;
                        pipeDirectionChange = true;
                    } else if (x-1 >= 0 && y-1 >= 0 && region[y-1][x-1] == currentRegionId) {
                        currentPoint[0] -= 1;
                        currentPoint[1] -= 1;
                    } else if (y-1 >= 0 && region[y-1][x] == currentRegionId) {
                        currentPoint[1] -= 1;
                    } else if (x+1 < xSize && y-1 >= 0 && region[y-1][x+1] == currentRegionId) {
                        currentPoint[0] += 1;
                        currentPoint[1] -= 1;
                    } else {
                        if (y-1 >= 0 && seed[0] < 0 && done[y-1][x] != REGION_DONE) {
                            //seed[0] = x;
                            //seed[1] = y-1;
                        }
                        currentDirection = DIRECTION_RIGHT;
                        currentPointNotChanged = true;
                    }
                    break;
                }

                
                // pipe direction change, re-calculate latHalfMargin and lonHalfMargin with new
                // value for currentDirection
                if (pipeDirectionChange) {
                    latHalfMargin = normal[currentDirection][0] * step/2;
                    lonHalfMargin = normal[currentDirection][1] * step/2;
                }

                boolean ignore = false;
                if (currentPointNotChanged) {
                    noChangeCount++;
                    /*if (noChangeCount >= 2) {
                        // find whether forward slash or backward slash
                        int refX, refY;
                        refX = x + (int)backward[currentDirection][1];
                        refY = y + (int)backward[currentDirection][0];
                        if (refX > 0 && refY > 0 && refX < xSize-1 && refY < ySize-1) { // don't bother if x,y are the border of the grid frame.
                            //System.out.println("NC detected for point: " + currentPoint[0] + "," + currentPoint[1]);
                            boolean forwardSlash, backSlash;
                            double bkLatMargin, bkLonMargin;
                            switch(currentDirection) {
                            case DIRECTION_RIGHT:
                                forwardSlash = (refY-1 < ySize && refX+1 >= 0 && region[refY][refX] == region[refY-1][refX+1]);
                                backSlash = (refY+1 >= 0 && refX+1 >=0 && region[refY][refX] == region[refY+1][refX+1]);
                                bkLatMargin = diagLatMargin + normal[currentDirection][0]*step;
                                bkLonMargin = diagLonMargin + normal[currentDirection][1]*step;
                            break;
                            case DIRECTION_LEFT:
                                forwardSlash = (refY+1 < ySize && refX-1 >= 0 && region[refY][refX] == region[refY+1][refX-1]);
                                backSlash = (refY-1 >= 0 && refX-1 >=0 && region[refY][refX] == region[refY-1][refX-1]);
                                bkLatMargin = diagLatMargin + normal[currentDirection][0]*step;
                                bkLonMargin = diagLonMargin + normal[currentDirection][1]*step;
                                break;
                            case DIRECTION_UP:
                                forwardSlash = (refY-1 < ySize && refX+1 >= 0 && region[refY][refX] == region[refY-1][refX+1]);
                                backSlash = (refY-1 >= 0 && refX-1 >=0 && region[refY][refX] == region[refY-1][refX-1]);
                                bkLatMargin = diagLatMargin + normal[currentDirection][0]*step;
                                bkLonMargin = diagLonMargin + normal[currentDirection][1]*step;
                                break;
                            case DIRECTION_DOWN:
                                forwardSlash = (refY+1 < ySize && refX-1 >= 0 && region[refY][refX] == region[refY+1][refX-1]);
                                backSlash = (refY+1 >= 0 && refX+1 >=0 && region[refY][refX] == region[refY+1][refX+1]);
                                bkLatMargin = diagLatMargin + normal[currentDirection][0]*step;
                                bkLonMargin = diagLonMargin - normal[currentDirection][1]*step;
                                break;
                            default:
                                forwardSlash = false;
                                backSlash = false;
                                break;
                            }
                            
                            if (forwardSlash && backSlash) {
                                ignore = false;
                            } else {
                                if (forwardSlash) contour.add(new double[]{latmint + y*step + diagLatMargin, lonmint + x*step + diagLonMargin});
                                if (backSlash) contour.add(new double[]{latmint + y*step + diagLatMargin + normal[currentDirection][0]*step, lonmint + x*step + diagLonMargin + normal[currentDirection][1]*step});
                                ignore = true;
                            }
                        }
                    }*/
                } else {
                    noChangeCount = 0;                    
                }
                
                if (!ignore) {
                    contour.add(new double[]{latmint + y*step + latHalfMargin, lonmint + x*step + lonHalfMargin});
                }
            }
            ret.add(contour);
            contourIndices.add(new double[]{currentRegionId});
            // If no out edge was found, probably island occurred. This can be found by raster
            // scan in the form of light arrow shooting. Let's say we shoot light from left
            // and let the light get obstructed as region change is detected. The obstruction
            // is considered valid if the found border point has not be processed earlier.
            // Otherwise, the light is allowed to pass through searching for another seed
            seed[0] = seed[1] = -1; // Set seed to unreasonable value
            for (int i=0; i<ySize; i++) {
                // shooting the ray along x-axis from left to right for each row
                int regionId = -1; // some negative value initialization
                for (int j=0; j<xSize; j++) {
                    if (region[i][j] != regionId) {
                        regionId = region[i][j];
                        if (done[i][j] != REGION_DONE) {
                            seed[0] = j;
                            seed[1] = i;
                            break;
                        }
                    }
                }
                if (seed[0] != -1 && seed[1] != -1) {
                    break;
                }
            }
        }
        /*System.out.println("Latmin: " + latmint);
        System.out.println("Latmax: " + latmaxt);
        System.out.println("Longmin: " + lonmint);
        System.out.println("Longmax: " + lonmaxt);*/

        ret.add(contourIndices);
        System.out.println("Time for contour generation: " + (System.currentTimeMillis() - contourStart) + "milli sec");
        System.out.println("Contour counts: " + ret.size());
        return ret;
    }

    private void debugDoneArrayImage(int[][] done, int xSize, int ySize)  throws IOException
    {
        if (!writeDebugImages) {
            return;
        }
        double [] imgData = new double[xSize * ySize];
        for (int y=0; y<ySize; y++) {
            for (int x=0; x<xSize; x++) {
                imgData[y * xSize + x ] = done[y][x] == REGION_DONE ? 180 : 0;
            }
        }
        BufferedImage bi = new BufferedImage(xSize, ySize, BufferedImage.TYPE_BYTE_GRAY);
        WritableRaster raster = (WritableRaster) bi.getData();
        raster.setPixels(0, 0, xSize, ySize, imgData);
        bi.setData(raster);
        File outputfile = new File("/tmp/doneData.png");
        ImageIO.write(bi, "png", outputfile);
    }

    public String listToJson(List<List<double []>> ret) {
        String s = "[";
        List<double []> oneLine;
        for (int i=0; i<ret.size(); i++) {
            s += "[";
            oneLine = ret.get(i);
            for (int j=0; j<oneLine.size(); j++) {
                s += "[" + oneLine.get(j)[0] + "," + oneLine.get(j)[1] + "]";
                if (j < oneLine.size() -1) {
                    s += ",";
                }
            }
            s += "]";
            if (i < ret.size() -1) {
                s += ",";
            }
        }
        s += "]";
        return s;
    }
}
