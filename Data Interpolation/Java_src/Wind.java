/* Ozone value interpolation using wind speed and direction.
 * 
 * Author: John Naruk (john.naruk@gmail.com)
 * Modified By: Sushil Joshi (sjoshi4@mail.uh.edu)
 */
package LatLongInterpolation_testing;

import java.util.Scanner;
import java.io.*;

public class Wind
{
    public static void printArray(int[] array)
    {
        for(int x:array)
        System.out.print(x+"\t");
        System.out.println();
    }
    
    public static void printArray(double[] array)
    {
        for(double x:array)
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
        return Math.min(a,Math.PI*2-a);
    }
    
    /**The number of points to include in each approximation*/
    private final int INCLUDED_POINTS=10;
    /**The conversion from MPH wind to KPH*/
    private final double KILOMETERS_PER_MILE = 1.609;
    
    /**The number known of points in the approximation*/
    public int points=0;
    public double[][] coordinates = new double[1][2];
    public double[][] values = new double[1][2];
    public boolean[] nulls = new boolean[1];
    
    /**The minimum x values of all stations.  This is initialized with a high value so the first value added overwrites it.*/
    public double latmin = Math.pow(10,1000);
    /**The maximum x values of all stations.  This is initialized with a low value so the first value added overwrites it.*/
    public double latmax = -Math.pow(10,1000);
    /**The minimum y values of all stations.  This is initialized with a high value so the first value added overwrites it.*/
    public double lonmin = Math.pow(10,1000);
    /**The maximum y values of all stations.  This is initialized with a low value so the first value added overwrites it.*/
    public double lonmax = -Math.pow(10,1000);
    
    public int unique;
    public DataScanner spdWindSource;
    public DataScanner dirWindSource;
    public boolean locationstarted=false;
    public int[] index;
    public double[] distanceWeight;
    public double[] angleWeight;
    public double[][] vectors;
    
    /**
     * Creates a new wind approximation system.
     * A wind approximation must be created separately for use in the Ozone program.
     * It does not do anything besides create the object
     */
    Wind(){}
    
    /**
     * Adds a new wind station.
     * @param x The x coordinate of the station
     * @param y The y coordinate of the station
     */
    public void newStation(double lat,double lon)
    {
        //Increments the array length
        double[][] oldcoordinates = coordinates.clone();
        coordinates = new double[points+1][2];
        values = new double[points+1][2];
        nulls = new boolean[points+1];
        System.arraycopy(oldcoordinates,0,coordinates,0,points);
        //Stores the location of the new station
        coordinates[points][0]=lat;
        coordinates[points][1]=lon;
        //Resets the maximum and minimum values for station locations
        latmin = Math.min(latmin,lat);
        latmax = Math.max(latmax,lat);
        lonmin = Math.min(lonmin,lon);
        lonmax = Math.max(lonmax,lon);
        points++;
    }
    
    /**
     * Loads a set of coordinates for wind points from given data.
     * @param stationCoordinates
     * 
     */
    public void loadStations(double[][] stationCoordinates)
    {
        DataScanner inCoordinates = new DataScanner(stationCoordinates);
        while(true)//Placing the breakout condition after each value is added is the most efficent way to run this
        {
            double lat;
            double lon;
            //gets the x and y coordinates if in the file and breaks if no more numbers are in the file
            if(inCoordinates.hasNextDouble()) lat=inCoordinates.nextDouble();
            else break;
            if(inCoordinates.hasNextDouble()) lon=inCoordinates.nextDouble();
            else break;
            newStation(lat,lon);
            inCoordinates.nextLine();
        }
    }
    
    /**
     * Loads a set of coordinates for wind points from given data
     * @param spdData wind speed values for the stations
     * @param dirData wind direction values for the stations
     * 
     */
    public void setValueSources(double[][] spdData, double[][] dirData)
    {
    	spdWindSource = new DataScanner(spdData);
    	dirWindSource = new DataScanner(dirData);
    }
    
    /**
     * Loads a new set of wind values from the file
     */
    public void loadNextValues()
    {
        for(int i=0;i<points && spdWindSource.hasNextDouble() && dirWindSource.hasNextDouble();i++)
        {
            double spd = spdWindSource.nextDouble();
            double dir = dirWindSource.nextDouble();
            if(spd<0||dir<0)
            {
                nulls[i]=true;
                values[i][0]=0;
                values[i][1]=0;
            }
            else
            {
                nulls[i]=false;
                values[i][0] = spd*Math.cos(dir*Math.PI/180)*KILOMETERS_PER_MILE;
                values[i][1] = spd*Math.sin(dir*Math.PI/180)*KILOMETERS_PER_MILE;
            }
        }
        spdWindSource.nextLine();
        dirWindSource.nextLine();
    }
    
    /**
     * Specifies new values for the wind system
     * @param newvalues the set of new values
     */
    public void setValues(double[] spd,double[] dir)
    {
        for(int i=0;i<spd.length && i<dir.length;i++)
        {
            if(spd[i]<0||dir[i]<0)
            {
                nulls[i]=true;
                values[i][0]=0;
                values[i][1]=0;
            }
            else
            {
                nulls[i]=false;
                values[i][0] = spd[i]*Math.cos(dir[i]*Math.PI/180);
                values[i][1] = spd[i]*Math.sin(dir[i]*Math.PI/180);
            }
        }
    }
    
    /**
     * Sets the location for the approximation and finds the weights for the wind points.
     * @param x The x coordinate of the location
     * @param y The y coordinate of the location
     */
    public void setLocation(double lat,double lon)
    {
        //Calculates the distances between the point of approximation and all known points
        distanceWeight = new double[points];
        index = new int[INCLUDED_POINTS+2];
        vectors = new double[INCLUDED_POINTS][2];
        angleWeight = new double[INCLUDED_POINTS];
        unique=-2;
        for(int i=0;i<points;i++)
        {
            if(nulls[i])
            {distanceWeight[i] = 0;}
            else if(lat==coordinates[i][0]&&lon==coordinates[i][1])
            {
                unique=i;
                return;
            }
            else
            {distanceWeight[i] = 1/( Math.pow(coordinates[i][0]-lat,2) + Math.pow((coordinates[i][1]-lon)*Math.cos(coordinates[i][0]*Math.PI/180),2));} // inverse of the distance as per Pythagoras' theorem on equirectangular projection
        }
        //Creates lists for the indicies of the points to include in further calculations based on which are closest including the time distance for wind points
        for(int i=0;i<index.length;i++)index[i]=-1;
        for(int i=1;i<points;i++)
        {
            //The list of indicies is kept in order of which is closest as they are added to this list or skipped if farther away
            for(int k=INCLUDED_POINTS;k>=0 && (index[k]==-1 || distanceWeight[i] > distanceWeight[index[k]]);k--)
            {
                index[k+1]=index[k];
                index[k]=i;
            }
        }
        //Calculates the vectors between the point of approximation and the points to be included.  Those left out by the previous loop are ignored for the rest of the method
        vectors = new double[INCLUDED_POINTS][2];
        for(int i=0;i<INCLUDED_POINTS;i++)
        {
            vectors[i][0] = coordinates[index[i]][0]-lat;
            vectors[i][1] = (coordinates[index[i]][1]-lon)*Math.cos(coordinates[index[i]][0]*Math.PI/180);
        }
        //Calculates the smallest positive and negative angle weights and averages them for the final angle weight
        for(int i=0;i<INCLUDED_POINTS;i++)
        {
            for(int j=0;j<INCLUDED_POINTS;j++)
            {angleWeight[i]+=getAngle(vectors[i],vectors[j]);}
        }
        locationstarted=true;
    }
    
    /**
     * Gives the x component of the wind at the point specified by setLocation.
     * @return the x component of the wind
     */
    public double getWindX()
    {
        if(!locationstarted) return 0;
        if(unique>=-1) return values[unique][0];
        double weight=0;
        double weightTotal=0;
        double valueTotal=0;
        for(int i=0;i<INCLUDED_POINTS;i++)
        {
            weight = (distanceWeight[index[i]]-distanceWeight[index[INCLUDED_POINTS]])*angleWeight[i];
            weightTotal += weight;
            valueTotal += values[index[i]][0]*weight;
        }
//        printArray(angleWeight);
//        printArray(distanceWeight);
        return valueTotal/weightTotal;
    }
    
    /**
     * Gives the y component of the wind at the point specified by setLocation.
     * @return the y component of the wind
     */
    public double getWindY()
    {
        if(!locationstarted) return 0;
        if(unique>=-1) return values[unique][1];
        double weight=0;
        double weightTotal=0;
        double valueTotal=0;
        for(int i=0;i<INCLUDED_POINTS;i++)
        {
            weight = (distanceWeight[index[i]]-distanceWeight[index[INCLUDED_POINTS]])*angleWeight[i];
            weightTotal += weight;
            valueTotal += values[index[i]][1]*weight;
        }
        return valueTotal/weightTotal;
    }
}
