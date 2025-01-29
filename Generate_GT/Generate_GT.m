function GT = Generate_GT(sample,threshold_shift)
    % Generates an automatic Ground Truth from a hypercube. 
    % Requires manual review of results by the user.
    %
    % INPUTS
    %       sample            [hypercube]   -> Spectral cube for GT generation.
    %       threshold_shift   [double]      -> Multiplier to add or subtract the STD from the threshold. 
    %                                       Allows to manually modify the intensity up to which the ink is considered as foreground.
    %
    % OUTPUT
    %       GT                [logical]     -> GT generated from the input. Binary image. 
    %                         m x n         Requires manual review.
    %
    % Based on:
    % Ntirogiannis, Konstantinos & Gatos, Basilios & Pratikakis, Ioannis. (2008). 
    % "An Objective Evaluation Methodology for Document Image Binarization Techniques". 
    % 10.1109/DAS.2008.41.
    %
    % Color Imaging Laboratory, Department of Optics, University of
    % Granada, Spain. colorimg@ugr.es
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % If no threshold shift is selected, it's considered as 0 by default
    if nargin < 2
        threshold_shift=0;
    end

    % Obtaining the band index with the highest contrast.
    best_band = best_band_from_cube(sample);
    
    % Extracting the best band image.
    image=sample.DataCube(:,:,best_band);

    % Identifying the edges with Canny filter.
    edges = edge(image,'canny',0.4);
    
    % Complementary to the image so that in the GT the ink corresponds to the white pixels and the background to the black pixels.
    samplecomplement = imcomplement(image);

    % Binarizing the image for skeletonization.
    BW = imbinarize(samplecomplement);

    % Skeletonization of the binarization.
    skeleton = bwskel(BW);
    
    % The output GT will be a binary image with the same size as the skeleton.
    [row,col] = size(skeleton);
    GT=imbinarize(skeleton*0);
    
    % The gray threshold is calculated as the mean value of the edges.
    edgevector=[];
    n=0;
    for ii = 1:row
        for jj = 1:col
            if edges(ii,jj) == 1
                n=n+1;
                edgevector(n)=image(ii,jj);
            end
        end
    end
    
    % Adition of the threshold shift multiplied by the standard deviation.
    threshold = mean(edgevector)+threshold_shift*std(edgevector);

    % Dilation, each pixel from the skeleton grows to left, right, up and down until it reaches an edge.
    for dilate = 1:100 % Dilation iterations.
        for ii = 1:row
            for jj = 1:col

                % Growth of every skeleton pixel.
                if skeleton(ii,jj) == 1
                    for w = -1:1
                        % Dilation will stop when it reaches a threshold.
                        if ii+w >=1 && ii+w <= row
                            if image(ii+w,jj) <= threshold
                                GT(ii+w,jj) = 1;
                            end
                        end
                        if jj+w >=1 && jj+w <= col
                            if image(ii,jj+w) <= threshold
                                GT(ii,jj+w) = 1;
                            end
                        end
                    end
                end
            end
        end
        skeleton = GT; % On the next iteration, the dilated skeleton will grow again.
    end
end

%% Auxiliary function:
function best_band = best_band_from_cube(cube)
    % Obtains the best band from a hypercube.
    %
    % INPUTS
    %       cube              [hypercube]   -> Spectral cube.
    %
    % OUTPUT
    %       best_band         [integer]     -> Index of the best band for the spectral cube.
    %
    % Color Imaging Laboratory, Department of Optics, University of Granada, Spain.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Getting the hyperspectral data from the cube variable.
    hypercube = cube.DataCube;
    
    % Inicialization of noise values.
    bands_number = size(hypercube,3);
    noise_values = zeros(1,bands_number);
    
    % Loop for calculating the noise value for each band.
    for k = 1:bands_number
        % Selects band k
        band = hypercube(:,:,k);
    
        % Calculates the Signal-to-Noise Ratio (SNR) for band k.
        average = mean2(band); % 2D mean of the band.
        standard_deviation = std2(band); % 2D std of the band.
        noise_values(k) = 10 * log10(average^2 / standard_deviation^2); % SNR formula.
    end
    
    % Identifies the band with the lowest SNR.
    [~, best_band] = min(noise_values);
end