#### Approach

Our app generates fake heart rate samples and store back to *HKHealthStore*. The samples are ranging in between 50 to 60. Users can adjust the heart rate data insertion rate and the insertion time. While storing the data, our app will provide statistics how many successful and failed operations, as well as real-time insertion rate. When the task is done, the app automatically query how many data points are in the HKHealthStore to verify the data points are really going through. 

#### Result

On iPhone 5s, we can insert around 1030 data samples per second.

#### Warning

Adding fake data may mess your existing health data. Please run the app at your own risk.

