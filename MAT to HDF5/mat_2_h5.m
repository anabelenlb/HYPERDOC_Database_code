function mat_2_h5

% This function transform hypercubes from MAT to HDF5.
%
% Color Imaging Laboratory, Department of Optics, University of Granada,
% Spain. colorimg@ugr.es
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
tic
% Select a folder with all cubes to be processed.
folder_name_load = uigetdir(pwd,'Select hypercubes folder:');
cd(folder_name_load)
d = dir('*.mat');
mkdir('HDF5') % Creates HDF5 folder to save the processed cubes.
for i = 1:length(d)
    cd(folder_name_load)
    filename = d(i).name;
    clc, disp(['Converting file ' num2str(i) ' of ' num2str(length(d))])
    load(filename)
    % Extract information from the hypercube:
    cd HDF5
    cube = cube.DataCube;
    h5_filename = strcat(filename(1:end-4),'.h5');

    % Create the file:
    h5create(h5_filename,'/DataCube',size(cube))

    % Store the cube:
    h5write(h5_filename,'/DataCube',cube)

    % Include Metadata as attributes

    fn = fieldnames(Metadata);
    for i=1:numel(fn)
        if islogical(Metadata.(fn{i})) == 1
            h5writeatt(h5_filename,'/',fn{i},uint8(Metadata.(fn{i})))
            continue
        elseif iscell(Metadata.(fn{i})) == 1
            h5writeatt(h5_filename,'/',fn{i},string(Metadata.(fn{i})))
            continue
        end
        h5writeatt(h5_filename,'/',fn{i},Metadata.(fn{i}))
    end
end
toc