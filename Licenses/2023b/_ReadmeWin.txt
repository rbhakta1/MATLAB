
0. Mount iso-file  R2023b_Windows.iso  to virtual disk.
     For Windows 8 and lower you probably need soft like Daemon Tools Lite (or similar)

1. Run setup.exe from that virtual disk and if you see login/password/signin form (you gave access to internet for installer)
     then in upper right corner in  "Advanced Options"  select setup mode  "I have a File Installation Key"
     If internet access is absent then required setup mode will be auto-selected and you do not need to select it manually

2. When you will be asked to  "Enter File Installation Key"  enter

 19888-45209-61323-29230-25497-43412-35108-15123-25580-54377-05875-31006-25681-45018-46907-09460-23253-25339-58435-17194-52867-38929-08174-61608-35890-10321 
2.1 MATLAB R2023a Parallel Server:
 11317-39170-30581-06794-33638-30864-39215-17095-10747-02684-27090-22009-16584-56488-15039-17855-31650-45204-02949-59443-61430-56121-38824-55110-16755 

3. When you will be asked to  "Select License File"  select file  "license.lic"  from folder with  Matlab913_R2022b_Win64.iso  file

4. Then select folder where you want Matlab to be installed (<matlabfolder>)

5. When you will be asked to  "Select products"  select components you need
     If you all components are selected Matlab will need about 30Gb of disk space and somewhat longer startup time
     If you select only  "MATLAB"  then Matlab will need about  3Gb of disk space
     You better install Matlab on SSD disk for better startup time, so most likely you do not want to waste SSD-disk space for nothing

6. Then in  "Select Options"  select  "Add shortcut to desktop"

7. Components setup progress may be shown incorrectly (for example always show 0%) ... just wait
     Or if installation process takes too long start to monitor size of <matlabfolder> folder
     If the size is not growing after several minutes then restart setup from step 1

8. After installation is done copy file  "libmwlmgrimpl.dll"  from folder with  R2023b_Windows.iso  file
     to ALREADY EXISTING FOLDER  "<matlabfolder>\bin\win64\matlab_startup_plugins\lmgrimpl"
     WITH OVERWRITING OF EXISTING FILE (<matlabfolder> - is where you have selected to install Matlab on step 4)
     If you was NOT asked about overwriting then you are doing something wrong (or Matlab was not installed successfully)!!!
8.1 for polyspace replace the libmwlmgrimpl on this path:C:\Program Files\Polyspace\R2023a\bin\win64\matlab_startup_plugins\lmgrimpl

9. If desktop shortcut was not created (or was created bad shortcut)
     then create new shortcut or change existing one so that it run the
     "<matlabfolder>\bin\win64\MATLAB.exe"

10. Work with Matlab :)

P.S Some Addons or Product may not avaiable!

P.S.
If setup hang in step 1-7 then force to close it and start setup again from step 1

P.S.2
During update/change of already working Matlab there is no need to execute step 3
Step 8 might be necessary to repeat (if during update/change of Matlab file  "libmwlmgrimpl.dll"  was overwritten)
If after update/change you get error during startup of Matlab then first try to redo the step 8
