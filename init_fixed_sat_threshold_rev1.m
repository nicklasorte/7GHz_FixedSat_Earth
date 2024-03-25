clear;
clc;
close all;
close all force;
app=NaN(1);  %%%%%%%%This is for me and APPs
format shortG
top_start_clock=clock;
folder1='C:\Local Matlab Data\7-8GHz'  %%%%%Folder where all the matlab code is placed.
cd(folder1)
addpath(folder1)
addpath('C:\Local Matlab Data\General_Terrestrial_Pathloss')  %%%%%%%%Where we will put the pathloss functions.
%addpath('C:\Local Matlab Data\Generic_FDR')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Load in the fix-sat Lat/Lon
load('Uni_Fix_Sat_7250_7750.mat','table_uni_rows')
table_header=table_uni_rows.Properties.VariableNames;
fix_sat_data=table2cell(table_uni_rows);
unique(fix_sat_data(:,4))


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Load in the fix-sat equipment parameters
tf_pull_fix_sat_excel=0%1
num_xlsx=1;
fix_sat_excel_filename1='fix_sat_equipment_3_22_2024.xlsx';
filename_cell_fix_sat_earth=strcat('cell_fix_sat_earth_',num2str(num_xlsx),'.mat');
[var_exist_cell1]=persistent_var_exist_with_corruption(app,filename_cell_fix_sat_earth);
if tf_pull_fix_sat_excel==1
    var_exist_cell1=0;
end
if var_exist_cell1==2
    tic;
    load(filename_cell_fix_sat_earth,'cell_fix_sat_earth')
    toc;
else
    tic;
    cell_fix_sat_earth=readcell(fix_sat_excel_filename1);
    toc;
    tic;
    save(filename_cell_fix_sat_earth,'cell_fix_sat_earth')
    toc;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
name_col_idx=find(matches(cell_fix_sat_earth(1,:),'System_Name'));
bw_col_idx=find(matches(cell_fix_sat_earth(1,:),'Bandwidth_Rx_MHz_Full'));
nf_col_idx=find(matches(cell_fix_sat_earth(1,:),'NoiseFloor_Rx_dB'));
temp_col_idx=find(matches(cell_fix_sat_earth(1,:),'Rx_Noise_Temp_Kelvin'));


%%%%%%%Merge the data:
generic_rx_nf=1.5;
generic_rx_bandwidth_mhz=100;
generic_temp_kelvin=125;
fix_sat_rx_height_m=3; %%%%%%%%%%3 meters is a placeholder.

%%%%%%%%%%%Calculate the threshold:
in_ratio=-6; %%%%%I/N Ratio -6dB
commerical_tx_bandwidth_MHz=100 %%%%%%%%%100MHz
ant_gain=-10 %%%%%%%%%%%dBi at the horizon (placeholder)
boltz=1.38064852*10^-23

%%%%%%%%%%%%%%Calculate the DPA threshold for the fixed satellites
[num_rows,~]=size(fix_sat_data)
cell_fix_sat_earth_data=horzcat(fix_sat_data,cell(num_rows,4)); %%%%%%1)Agency, 2)City, 3)State, 4)Equipment, 5)Lat, 6)Lon, 7)Equipment Bandwidth, 8)Noise Temp K, 9)Noise Floor, 10)"CBRS Threshold"
for i=1:1:num_rows
   match_row_idx=find(matches(cell_fix_sat_earth(:,name_col_idx),fix_sat_data{i,4}));
   if ~isempty(match_row_idx)
       cell_fix_sat_earth_data{i,7}=cell_fix_sat_earth{match_row_idx,bw_col_idx};
       cell_fix_sat_earth_data{i,8}=cell_fix_sat_earth{match_row_idx,temp_col_idx};
       cell_fix_sat_earth_data{i,9}=cell_fix_sat_earth{match_row_idx,nf_col_idx};

       if ischar(cell_fix_sat_earth_data{i,9})
           if contains(cell_fix_sat_earth_data{i,9},'N/A')
               cell_fix_sat_earth_data{i,9}=generic_rx_nf;
           end
       end
   else
       cell_fix_sat_earth_data{i,7}=generic_rx_bandwidth_mhz;
       cell_fix_sat_earth_data{i,8}=generic_temp_kelvin;
       cell_fix_sat_earth_data{i,9}=generic_rx_nf;
   end
   %%%%%%%%%Threshold
   temp_kelvin=cell_fix_sat_earth_data{i,8};
   rx_bandwidth_mhz=cell_fix_sat_earth_data{i,7};
   rx_nf=cell_fix_sat_earth_data{i,9};
   ktb=10*log10((boltz*temp_kelvin)*1000);
   on_tune_reject=10*log10(commerical_tx_bandwidth_MHz/rx_bandwidth_mhz);
   cell_fix_sat_earth_data{i,10}=ktb+10*log10(rx_bandwidth_mhz*10^6)+rx_nf-ant_gain+in_ratio+on_tune_reject;
% %    ktb+10*log10(rx_bandwidth_mhz*10^6)
% %    ktb+10*log10(rx_bandwidth_mhz*10^6)+rx_nf
% %    ktb+10*log10(rx_bandwidth_mhz*10^6)+rx_nf-ant_gain
% %    ktb+10*log10(rx_bandwidth_mhz*10^6)+rx_nf-ant_gain+in_ratio
% %    ktb+10*log10(rx_bandwidth_mhz*10^6)+rx_nf-ant_gain+in_ratio+on_tune_reject
end


cell_fix_sat_earth_data


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Simulation Input Parameters to change
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rev=1000; %%%%%%Fix Sate Coordination Example:
sim_radius_km=200; %%%%%%%%Placeholder distance --> Simplification: This is an automated calculation, but requires additional processing time.
grid_spacing=30;  %%%%km:
bs_eirp=85; %%%%%EIRP [dBm/100MHz] 65dBm/1MHz --> 75dBm/10Mhz --> 85dBm/100Mhz
bs_height=30; %%%%%Height in m
array_mitigation=0:10:60;  %%%%%%%%% in dB
%%loc_idx1=find(contains(cell_fix_sat_earth_data(:,2),'FT BELVOIR'));
cell_locations=cell_fix_sat_earth_data;%%([loc_idx1],:)
tf_calc_rx_angle=0;  %%%%%%0 assumes everything is coming in at the sidelobe.
sim_folder1=folder1
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%






%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Propagation Inputs
FreqMHz=7250; %%%%%%%%MHz (Lowest Frequency for now)
reliability=50;
array_reliability_check=reliability;
confidence=50;
Tpol=1; %%%polarization for ITM
array_bs_eirp_reductions=bs_eirp; %%%%%Rural, Suburban, Urban cols:(1-3)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Piece together the cell_sim_data
[num_sites,~]=size(cell_locations)
cell_sim_data=cell(num_sites,15);
for i=1:1:num_sites
    %%%%%%Remove the Space in Column #2:
    temp_city=cell_locations{i,2};
    cell_sim_data{i,1}=erase(temp_city," ");

    %%%%%%%%%Lat/Lon to a single cell
    temp_latlon=cell2mat(cell_locations(i,[5,6]));
    temp_latlon(:,3)=fix_sat_rx_height_m;
    cell_sim_data{i,2}=temp_latlon;
    cell_sim_data{i,3}=temp_latlon;

end

[uni_city,ia,ic]=unique(cell_sim_data(:,1));

%%%%%%Find those that aren't unique and add a number, just add a number to
%%%%%%all names.
for i=1:1:length(uni_city)
    match_row_idx=find(matches(cell_sim_data(:,1),uni_city{i}));
    for j=1:1:length(match_row_idx)
        temp_city=strcat(cell_sim_data{match_row_idx(j),1},num2str(j));
        cell_sim_data{match_row_idx(j),1}=temp_city;
    end
end

% % cell_sim_data(:,1)
% % [uni_city,~,~]=unique(cell_sim_data(:,1))


cell_sim_data(:,4)=cell_locations(:,10);
cell_sim_data(:,5)=num2cell(bs_eirp);
cell_sim_data(:,6)=num2cell(bs_height);
cell_sim_data(:,7)={array_mitigation};
cell_sim_data(:,8)=num2cell(grid_spacing);
cell_sim_data(:,9)={array_bs_eirp_reductions};
cell_sim_data(:,10)={reliability};
cell_sim_data(:,11)={confidence};
cell_sim_data(:,12)={FreqMHz};
cell_sim_data(:,13)={Tpol};
cell_sim_data(:,14)=num2cell(sim_radius_km);
array_threshold=cell2mat(cell_locations(:,10));
required_pathloss=ceil(array_bs_eirp_reductions-array_threshold);  %%%%%%%%%%%%%%%%%Round up
cell_sim_data(:,15)=num2cell(required_pathloss);

cell_sim_data


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Create a Rev Folder
cd(sim_folder1);
pause(0.1)
tempfolder=strcat('Rev',num2str(rev));
[status,msg,msgID]=mkdir(tempfolder);
rev_folder=fullfile(sim_folder1,tempfolder);
cd(rev_folder)
pause(0.1)


tic;
save('reliability.mat','reliability')
save('confidence.mat','confidence')
save('FreqMHz.mat','FreqMHz')
save('Tpol.mat','Tpol')
save('sim_radius_km.mat','sim_radius_km')
save('grid_spacing.mat','grid_spacing')
save('array_bs_eirp_reductions.mat','array_bs_eirp_reductions')
save('array_reliability_check.mat','array_reliability_check')
save('bs_height.mat','bs_height')
save('cell_sim_data.mat','cell_sim_data')
save('array_mitigation.mat','array_mitigation')
save('tf_calc_rx_angle.mat','tf_calc_rx_angle')
toc;




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Saving the simulation files in a folder for the option to run from a server
%%%%%%%%%For Loop the Locations
[num_locations,~]=size(cell_sim_data)
base_id_array=1:1:num_locations; %%%%ALL
table([1:num_locations]',cell_sim_data(:,1))

for base_idx=1:1:num_locations
    temp_single_cell_sim_data=cell_sim_data(base_idx,:);
    data_label1=temp_single_cell_sim_data{1};

    %%%%%%%%%Make a Folder each Location/System
    cd(rev_folder);
    pause(0.1)
    tempfolder2=strcat(data_label1);
    [status,msg,msgID]=mkdir(tempfolder2);
    sim_folder=fullfile(rev_folder,tempfolder2);
    cd(sim_folder)
    pause(0.1)

    tic;
    base_polygon=temp_single_cell_sim_data{2};
    save(strcat(data_label1,'_base_polygon.mat'),'base_polygon')

    base_protection_pts=temp_single_cell_sim_data{3};
    save(strcat(data_label1,'_base_protection_pts.mat'),'base_protection_pts')

    radar_threshold=temp_single_cell_sim_data{4};
    save(strcat(data_label1,'_radar_threshold.mat'),'radar_threshold')

    required_pathloss=temp_single_cell_sim_data{15};
    save(strcat(data_label1,'_required_pathloss.mat'),'required_pathloss')
    toc;
    strcat(num2str(base_idx/num_locations*100),'%')
end

cd(rev_folder)
pause(0.1)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Now running the simulation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tf_server_status=0;
parallel_flag=0;
wrapper_bugsplat_rev6(app,rev_folder,parallel_flag,tf_server_status)





end_clock=clock;
total_clock=end_clock-top_start_clock;
total_seconds=total_clock(6)+total_clock(5)*60+total_clock(4)*3600+total_clock(3)*86400;
total_mins=total_seconds/60;
total_hours=total_mins/60;
if total_hours>1
    strcat('Total Hours:',num2str(total_hours))
elseif total_mins>1
    strcat('Total Minutes:',num2str(total_mins))
else
    strcat('Total Seconds:',num2str(total_seconds))
end

cd(folder1)
pause(0.1)
