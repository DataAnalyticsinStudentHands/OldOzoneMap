/* Ozone value interpolation using wind speed and direction.
 * 
 * Author: John Naruk (john.naruk@gmail.com) 
 * Modified By: Sushil Joshi (sjoshi4@mail.uh.edu)
 */
package LatLongInterpolation_testing;

import java.io.*;
import java.util.List;

public class LatLongInterpolation
{
    /**
     * Expands an integer less than 10 into a 2 digit string for use in file names.
     * @param x The integer to be expanded
     * @return The string for the integer
     */
    public static String expand(int x)
    {
        if(x<10)
        return ("0"+x);
        return (""+x);
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
    
    public static void printArray(double[] array) 
    {
    	for (double x: array) System.out.print(x + "\t");
    	System.out.println();
    }
    
    public static void main(String[] args) throws FileNotFoundException, IOException
    {	
    	System.out.println("Started");
    	long start = System.currentTimeMillis();
    	LatLngDriver driver = new LatLngDriver();
    	List<List<double []>> contourList = driver.getContours();
    	//driver.drive();
    	//driver.getGridData();
    	
    	System.out.println(driver.gridExtent.toString());
    	System.out.println("Time Diff : " + (System.currentTimeMillis() - start));
    	System.out.println("Total Contour Count: " + contourList.size());
    }
}
