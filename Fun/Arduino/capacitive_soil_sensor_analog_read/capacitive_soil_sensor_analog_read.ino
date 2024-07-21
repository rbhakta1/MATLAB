void setup() {
int sensorPin = A0;    // select the input pin for the sensor
int sensorValue = 0;  // variable to store the value coming from the sensor
Serial.begin(9600);
}

void loop() {
  // read the input on analog pin 0:
  int sensorValue = analogRead(A0);
  // print out the value you read:
  Serial.println(sensorValue);
  delay(100);        // delay in between reads for stability
}
