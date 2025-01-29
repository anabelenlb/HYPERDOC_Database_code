% This script demonstrates how to process and analyze hyperspectral data from VNIR and SWIR minicubes stored in HDF5 format.
% It includes the following steps:
%   1. Load and explore the contents of the VNIR and SWIR minicubes.
%   2. Extract the hyperspectral data (DataCube) and wavelength information.
%   3. Display two false-color RGB images using specific bands from the VNIR and SWIR minicubes.
%   4. Load and display the Ground Truth (GT) image, which contains class labels for each pixel.
%   5. Calculate the mean and standard deviation of the spectral reflectance for each class in the GT.
%   6. Plot the mean spectral reflectance with standard deviation for both the VNIR and SWIR data.
%
% The resulting figures show the false-color image, GT, and spectral plots for each class.
% The only thing you have to do is to define the file names for your VNIR
% and SWIR minicubes.
%
% Color Imaging Laboratory, Department of Optics, University of Granada,
% Spain. colorimg@ugr.es
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Define the file names
filename_VNIR = '00007-VNIR-mock-up.h5';
filename_SWIR = '00007-SWIR-mock-up.h5';

% Explore the content of the VNIR minicube in the Command Window
h5info(filename_VNIR);

% Display metadata information for VNIR
h5disp(filename_VNIR);

% Read the datasets (hypercubes)
DataCube_VNIR = h5read(filename_VNIR, '/DataCube');
DataCube_SWIR = h5read(filename_SWIR, '/DataCube');

% Display a false-color RGB image using bands [50, 34, 9] in the VNIR minicube, 
% corresponding to wavelengths of 645 nm, 565 nm, and 440 nm, respectively
rgb_image_VNIR = DataCube_VNIR(:, :, [50 34 9]);
figure;
tiledlayout(2,3, 'Padding', 'none', 'TileSpacing', 'compact');
nexttile(1) % Create a subplot for the false-color RGB image
imshow(rgb_image_VNIR);
title('VNIR')

% Display a false-color RGB image using bands [141 61 21] in the SWIR minicube, 
% corresponding to wavelengths of 1700 nm, 1300 nm, and 1100 nm, respectively
rgb_image_SWIR = DataCube_SWIR(:, :, [141 61 21]);
nexttile(4) % Create a subplot for the false-color RGB image
imshow(rgb_image_SWIR);
title('SWIR');

% Retrieve the wavelengths from the 'wl' attribute for both VNIR and SWIR
wl_VNIR = h5readatt(filename_VNIR, '/', 'wl');
wl_SWIR = h5readatt(filename_SWIR, '/', 'wl');

% Load the Ground Truth (GT) image
GT_name = strcat(filename_VNIR(1:end-3), '_GT.png');
GT_name = erase(GT_name,"-VNIR");
[cdata, map] = imread(GT_name);

% Create a subplot for the GT image
nexttile([2 1])
imshow(cdata, map);
title('GT');

% Convert minicubes and GT into matrices and vectors respectively:
cube_VNIR_matrix = reshape(DataCube_VNIR, [], length(wl_VNIR), 1);
cube_SWIR_matrix = reshape(DataCube_SWIR, [], length(wl_SWIR), 1);
GT_vect = reshape(cdata, [], 1);

% Get the unique labels in the GT
classes = unique(GT_vect);

% VNIR - Calculate the means and standard deviations for each class
for j = 1:length(classes)
    group = classes(j);
    rows = cube_VNIR_matrix(GT_vect == group, :);
    mean_values_VNIR(j, :) = mean(rows, 1);
    std_VNIR(j, :) = std(rows, [], 1);
end

% SWIR - Calculate the means and standard deviations for each class
for j = 1:length(classes)
    group = classes(j);
    rows = cube_SWIR_matrix(GT_vect == group, :);
    mean_values_SWIR(j, :) = mean(rows, 1);
    std_SWIR(j, :) = std(rows, [], 1);
end

% Plot the standard deviation and mean of the VNIR data
nexttile([2 1])
% Extract the GT colormap from the VNIR attribute
GT_cmap = h5readatt(filename_VNIR, '/', 'GT_cmap');

% VNIR - Standard deviation curves
curve_max_VNIR = mean_values_VNIR + std_VNIR;
curve_min_VNIR = mean_values_VNIR - std_VNIR;
a_VNIR = [wl_VNIR', fliplr(wl_VNIR')];
area_VNIR = [curve_min_VNIR, fliplr(curve_max_VNIR)];

% Plot the standard deviation and mean of the VNIR data
for i = 1:length(classes)
    hold on
    class = classes(i);
    y_VNIR = area_VNIR(i, :);
    fill(a_VNIR, y_VNIR, GT_cmap(class, :), 'FaceAlpha', 0.3, 'EdgeColor', GT_cmap(class, :));
end
for i = 1:length(classes)
    class = classes(i);
    plot(wl_VNIR, mean_values_VNIR(i, :), 'LineWidth', 2, 'Color', GT_cmap(class, :));
    hold on
end

% SWIR - Standard deviation curves
curve_max_SWIR = mean_values_SWIR + std_SWIR;
curve_min_SWIR = mean_values_SWIR - std_SWIR;
a_SWIR = [wl_SWIR', fliplr(wl_SWIR')];
area_SWIR = [curve_min_SWIR, fliplr(curve_max_SWIR)];

% Plot the standard deviation and mean of the SWIR data
for i = 1:length(classes)
    hold on
    class = classes(i);
    y_SWIR = area_SWIR(i, :);
    fill(a_SWIR, y_SWIR, GT_cmap(class, :), 'FaceAlpha', 0.3, 'EdgeColor', GT_cmap(class, :));
end
for i = 1:length(classes)
    class = classes(i);
    plot(wl_SWIR, mean_values_SWIR(i, :), 'LineWidth', 2, 'Color', GT_cmap(class, :));
    hold on
end

xlabel('Wavelength (nm)');
ylabel('Reflectance');
grid on;
ylim([0 1]);
xlim([400 1700]);

% Extract the labels for the legend
GTLabels = h5readatt(filename_VNIR, '/', 'GTLabels');

% Create a legend for the plot
f = get(gca, 'Children');
legend_std = [];
for i = 1:length(classes)
    legend_std = [f(i),legend_std];
end
legend(legend_std, GTLabels(:, 2), 'Location', 'north', 'FontSize', 10, 'NumColumns', 2);
