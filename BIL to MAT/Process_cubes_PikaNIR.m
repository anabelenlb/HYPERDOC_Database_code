function Process_cubes_PikaNIR(mode,stage,white_reflectance, crop, rotate, imageband, meta, binning,smoo)

% This code reads the hyperspectral data from spectral cubes captured with
% Resonon PikaNIR and Spectronon software. Please be sure to store in the
% same folder the files '.bil' (or '.bip' or '.bsq'), and their corresponding
% files (with the same name) '.hdr' containing metadata. This script
% processes all full cubes in the selected folder. Giving the option for
% manual crop, rotation and/or vertical or horizontal flip.
% The code assumes that, if captured on the linear stage (stage = linear)
% the white reference used for the flat field has a known spectral reflectance contained in white_reflectance.
% Use 'teflon_white_reflectance_PikaNIR.mat' file for teflon bar. Otherwise, if captured in the rotating tripod
% (stage = angular) no correction is performed to account for the white reference reflectance.
% If imageband is set different from 0, a '.png' image file is created with
% the selected bands as grayscale image or as false RGB image.
% The final cube is stored as a MATLAB Hypercube object.

% Example usage: Process_cubes_PikaNIR('ref','linear','Multi_90', true, true, [141 61 21], false, true,0);
%
% For a false RGB display of the resulting cubes type: imshow(cube.DataCube(:,:,[141 61 21]),[])
%
% INPUTS:   mode                [char]      -> 'raw', 'rad', 'ref. Capturing mode: raw, radiance or reflectance.
%           stage               [char]      -> 'linear': if captured in linear stage.
%                                           -> 'angular': if captured in rotating tripod.
%           white_reflectance   [char]      -> 'Multi_90', 'Multi_50', 'Multi_20', 'Multi_5', 'Sphere', 'Teflon'.
%                               [161 x 1]   ->  Otherwise Spectral reflectance of the reference white tile used for flat field correction.
%                                              when capturing on the linear stage. Only used if stage == 'linear'.
%           crop                [bool]      -> if 'true', the cubes will be cropped.
%           rotate              [bool]      -> if 'true', the cubes will be rotated or flipped.
%           imageband           [integer]   -> if set to integer value different from 0, a '.png' image of the selected band is created in grayscale.
%                               [triplet]   -> if set to a triplet of integer values, a '.png' image of a false RGB is crated with the three selected bands.
%           meta                [bool]      -> if true, the script allows to input and store metadata for each cube. Otherwise it does not.
%           binning             [bool]      -> if true, it assumes spectral binning is on during capture (168 bands). Otherwise assumes no binning during capture(336 bands).
%           smoo                [integer]   -> if 0, no smoothing is applied to the spectra. Otherwise, smoothing is applied with the span value indicated in smoo (recommended value 30).
%                                           -> if smoothing is selected, performance will be significantly slower.
%
% Color Imaging Laboratory, Department of Optics, University of Granada,
% Spain. colorimg@ugr.es
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    program = tic;
    
    % Load cube and metadata files:
    folder_name = uigetdir;
    cd(folder_name);
    d = dir('*.bil');
    d = cat(1,d,dir('*.bip'));
    d = cat(1,d,dir('*.bsq'));

    % Creation of directories for storing the cubes
    mkdir 'bil'
    mkdir 'png'
    mkdir 'mat'
    
    for i=1:length(d)
        % Setting of wavelengths depending on whether binning was used in the capture or not.
        wl = set_wl(binning);
        wl_new = (900:5:1700)';
        clc, disp(['Processing cube ' num2str(i) ' of ' num2str(length(d)) '...'])
        
        % Opening of .hdr file to get capture information.
        filename = d(i).name;
        filenametext = [filename '.hdr'];
        fileID = fopen(filenametext);
        for j = 1:2
            tline = fgets(fileID);  % go to line 2 of the hdr file.
        end
        interleave = tline(14:16);  
        tline = fgets(fileID);      % go to line 3 of the hdr file.
        data_type = str2double(tline(13:14));
        tline = fgets(fileID);      % go to line 4 of the hdr file.
        lines = str2double(tline(9:end-2));
        tline = fgets(fileID);      % go to line 5 of the hdr file.
        samples = str2double(tline(11:end-2));
        tline = fgets(fileID);      % go to line 6 of the hdr file.
        bands = str2double(tline(9:end-2));
        while ~strcmp(tline(1:7),'shutter')
            tline = fgets(fileID);
        end
        texp = str2double(tline(11:end));
        tline = fgets(fileID);
        while ~strcmp(tline(1:10),'byte order')
            tline = fgets(fileID);
        end
        byte_order = str2double(tline(14));
        tline = fgets(fileID);      % go to line 14
        fclose(fileID);
        header_offset = 0;
        switch data_type
            case 1
                precision = 'int8';
            case 2
                precision = 'int16';
            case 3
                precision = 'int32';
            case 4
                precision = 'float';
            case 12
                precision = 'uint16';
        end
    
        switch byte_order
            case 0
                bord = 'ieee-le';
            case 1
                bord = 'ieee-be';
        end
        siz = [lines, samples, bands];

        % Read spectral cube.
        cube = single(multibandread_m(filename,siz,precision,header_offset,interleave,bord));
        cube = interp_cube(wl,cube,wl_new);
        if strcmp(mode,'ref')
             % Setting of white reflectance
            white = set_white(white_reflectance);
            cube = cube .* repmat(reshape(white,1,1,length(white)),size(cube,1),size(cube,2));
        end
        
        close all;
        % Cropping of the cube, if selected.
        if crop == 1
            cube = cropint_PikaNIR_cube(cube);  % After croping press enter.
        end
        % Rotation of the cube, if selected.
        if rotate == 1
            im = cat(3,imadjust(cube(:,:,90)),imadjust(cube(:,:,90)),imadjust(cube(:,:,90)));
            figure, imshow(im,[]);
            clc, disp(['Processing cube ' num2str(i) ' of ' num2str(length(d)) '...'])
            prompt = {'\fontsize{15} Enter rotation angle in degrees (negative angles rotate clockwise):','\fontsize{15} Enter Left-Right flip flag (1 = true or 0 = false):','\fontsize{15} Enter Up-Down flip flag (1 = true or 0 = false)'};
            dlgtitle = 'Rotation / flip data';
            dims = [2 100];
            definput = {'90','0','0'};
            opts.Resize = 'on';
            opts.Interpreter = 'tex';
            answer = inputdlg(prompt,dlgtitle,dims,definput,opts);
            cube = rotate_flip_NIRint(cube,str2double(answer{1}),str2double(answer{2}),str2double(answer{3}));
            close all
            if imageband == 0
                [~] = create_maximized_figureint(1);
                imshow(cube(:,:,90),[]);
                title('Final cube to be saved');
                pause(0.5)
            end

        end
        % Generation of garyscale or false RGB image.
        if imageband ~= 0
            if (length(imageband)>1)
                im_cube = cat(3,imadjust(cube(:,:,imageband(1))),imadjust(cube(:,:,imageband(2))),imadjust(cube(:,:,imageband(3))));
            else
                im_cube = imadjust(cube(:,:,imageband(1)));
            end
            [~] = create_maximized_figureint(1);
            imshow(im_cube,[]); title('Final cube to be saved')
            pause(0.5)
            cd png
            imwrite(im_cube,[filename(1:end-3) 'png']);
            cd ..
        end
        
        % Hypercube variable generation.
        wl = wl_new;
        cube = hypercube(cube,wl);
        
        % Smoothing, if selected.
        if smoo ~= 0
            cube = smooth_hypercube(cube,smoo);
        end
        
        % Metadata generation, if selected.
        if meta
            prompt = {'\fontsize{15} Cube number:','\fontsize{15} Cube info:','\fontsize{15} Parent cube:',...
                      '\fontsize{15} Illumination','\fontsize{15} Reference white','\fontsize{15} Date',...
                      '\fontsize{15} Aged (No, Nat, Art):','\fontsize{15} Restored (0 or 1)','\fontsize{15} Substrate:',...
                      '\fontsize{15} Varnish (0 or 1):','\fontsize{15} Varnish type:' };
            dlgtitle = 'Metadata';
            dims = [2 100];
            if i == 1
                % Default metadata for the first cube.
                definput = {'0','This cube contains ...','0','Hallogen','Teflon','Modern','No','0','Paper','0','None'};
            else
                % For the rest of the cubes, the default metadata is the introduced by the user in the previous case.
                definput = {num2str(Metadata.number),Metadata.cubeinfo,Metadata.parent_cube,Metadata.illumination,...
                            Metadata.reference_white,Metadata.date,Metadata.aged,num2str(Metadata.restored),...
                            Metadata.substrate,num2str(Metadata.varnish),Metadata.varnish_type};
            end
            opts.Resize = 'on';
            opts.Interpreter = 'tex';
            answer = inputdlg(prompt,dlgtitle,dims,definput,opts);
            
            Metadata.number = str2double(answer{1});    % Cube number.
            Metadata.name = filename(1:end-4);          % Cube name.
            Metadata.wl = [false; false; true];         % Spectral range, [UVIS; VNIR; SWIR].
            Metadata.cubeinfo = answer{2};              % Sample information.
            Metadata.RGB = im_cube;                     % False RGB.
            Metadata.GT = [];                           % Empty metadata field for including a Ground Truth.
            Metadata.GTLabels = [];                     % Empty metadata field for including Ground Truth labels.
            Metadata.pixels_averaged = [];              % Empty metadata field for including the number of pixels averaged for the mean spectra.
            Metadata.spectra_mean = [];                 % Empty metadata field for including the mean spectra.
            Metadata.spectra_std = [];                  % Empty metadata field for including the mean standard deviation.
            Metadata.parent_cube = answer{3};           % Empty metadata field for including the parent cube name.
            Metadata.position = [];                     % Empty metadata field for including the position within the parent cube.
            Metadata.texp = texp;                       % Exposure time for the capture.
            Metadata.device = 'PikaNIR';                % Device used for the capture.
            Metadata.stage = stage;                     % Stage used for the capture.
            Metadata.illumination = answer{4};          % Illumination used for the capture.
            Metadata.reference_white = answer{5};       % Reference white used for correction.
            Metadata.height = size(cube.DataCube,1);    % Cube height.
            Metadata.width = size(cube.DataCube,2);     % Cube width.
            Metadata.bands = size(cube.DataCube,3);     % Cube number of bands.
            Metadata.date = answer{6};                  % Date of the sample.
            Metadata.aged = answer{7};                  % Aging process of the sample.
            Metadata.restored = str2double(answer{8});  % Whether the sample has been restored or not.
            Metadata.substrate = answer{9};             % Substrate of the sample.
            Metadata.varnish = str2double(answer{10});  % Whether the sample has varnish or not.
            Metadata.varnish_type = answer{11};         % Varnish type of the sample.
            cd mat
            save([filename(1:end-3) 'mat'],'cube','wl','Metadata','-v7.3')
            cd ..
        else
            cd mat
            save([filename(1:end-3) 'mat'],'cube','wl','texp','mode','stage','-v7.3')
            cd ..
        end

        movefile(filename,[pwd '\bil'])
        movefile([filename '.hdr'],[pwd '\bil'])

    end

    fclose('all');
    
    %% Finish:
    clc
    disp('Finished!')
    disp(['Total processing time = ' secs2hms(toc(program)) '.']); clear program
    make_a_beep(0.15,400);
    close all
end

%% Now the auxiliary functions are declared:

function cube = interp_cube(wl,cube,wl_new)
% Function for cube interpolation.
% INPUT
%       wl      -> original wavelengths.
%       cube    -> spectral cube.
%       wl_new  -> new wavelengths for interpolation.
% OUTPUT
%       cube    -> cube after interpolation.

    [r,c,b] = size(cube);
    cube = reshape(cube,r*c,b)';
    
    cube = interp1(wl,cube,wl_new);
    cube = reshape(cube',r,c,length(wl_new));
end
%*****************************************************

function croped_cube = cropint_PikaNIR_cube(cube)
% Function for cube cropping.
% INPUT
%       cube    -> spectral cube.
% OUTPUT
%       croped_cube    -> cube after cropping.
    isok = false;
    while ~isok
        % GUI for letting the user select the cropping of the cube.
        a = get(0,'MonitorPositions');
        f = create_maximized_figureint(size(a,1));
        subplot(1,2,1)
        imshow(cat(3,imadjust(cube(:,:,90)),imadjust(cube(:,:,90)),imadjust(cube(:,:,90))),[])
        title('Full cube (press enter after cropping)')
        
        h = imrect(gca); %#ok<*IMRECT>
        pos = round(getPosition(h));

        % Cropping with the positions selected by the user.
        if (pos(2)>0) && (pos(1)>0) && ((pos(2)+pos(4)-1)<size(cube,1)) && ((pos(1)+pos(3)-1)<size(cube,2))
            croped_cube = cube(pos(2):pos(2)+pos(4)-1,pos(1):pos(1)+pos(3)-1,:);
            subplot(1,2,2)
            imshow(cat(3,imadjust(croped_cube(:,:,141)),imadjust(croped_cube(:,:,61)),imadjust(croped_cube(:,:,21))),[])
            title('Croped cube')
    
            opts.Default = 'Yes. It is ok'; opts.Resize = 'on'; opts.Interpreter = 'tex';
            answer = questdlg('Is this OK?','Confirmation','Yes. It is ok','No. I want to repeat it',opts);
            switch answer
                case 'Yes. It is ok'
                    isok = true;
            end
        end
        close(f)
    end
end
%*****************************************************

function handler = create_maximized_figureint(sc)
% Function for creating maximized figures.
    a = get(0,'MonitorPositions');
    handler = figure('units','pixels','outerposition',a(sc,:));
end
%*****************************************************

function cuber = rotate_flip_NIRint(cube, angle, LR,UP)
% Function for cube rotation.
% INPUTS
%       cube    -> data cube to be rotated.
%       angle   -> rotation angle (-90 to 180). Negative angles rotate clockwise.
%       LR      -> flip left-right if set to true.
%       UP      -> flip up-down if set to true.
% OUTPUT
%       cuber   -> rotated cube.
    
    if UP
        cuber = flipud(imrotate(cube,angle));
    elseif LR
        cuber = fliplr(imrotate(cube,angle));
    else
        cuber = imrotate(cube,angle);
    end
end
%*****************************************************

function time_string=secs2hms(time_in_secs)
% Function for calculating the time in hours, minutes and seconds
% INPUTS
%       time_in_secs    -> time in seconds (like the output of command 'toc').
% OUTPUT
%       time_string     -> string containig the time in hours, minutes and seconds.
    time_string='';
    nhours = 0;
    nmins = 0;
    if time_in_secs >= 3600
        nhours = floor(time_in_secs/3600);
        if nhours > 1
            hour_string = ' hours, ';
        else
            hour_string = ' hour, ';
        end
        time_string = [num2str(nhours) hour_string];
    end
    if time_in_secs >= 60
        nmins = floor((time_in_secs - 3600*nhours)/60);
        if nmins > 1
            minute_string = ' mins, ';
        else
            minute_string = ' min, ';
        end
        time_string = [time_string num2str(nmins) minute_string];
    end
    nsecs = time_in_secs - 3600*nhours - 60*nmins;
    time_string = [time_string sprintf('%2.1f', nsecs) ' secs'];
end
%*****************************************************

function make_a_beep(duration,frequency)
% Function for making a sound when cubes processing is finished.
% INPUTS
%       duation     -> duration of the sound.
%       frequency   -> frequency of the sound.
    amp = 0.5;                        % amplitude (default 1).
    fs = 11025;                     % sampling frequency (default 11025).
    time = 0:1/fs:duration;
    a = amp * sin(2 * pi * frequency * time);
    sound(a)
    
end
%*****************************************************

function im = multibandread_m(filename,dims,precision,offset,interleave,byteOrder,varargin)
    narginchk(6,9);
    nargoutchk(0,4);
    
    % Check input values.
    filename = convertStringsToChars(filename);
    precision = convertStringsToChars(precision);
    interleave = convertStringsToChars(interleave);
    byteOrder = convertStringsToChars(byteOrder);
    
    if nargin > 6
        isCell = cellfun(@(x) iscell(x), varargin);
        if ~isempty(varargin(isCell))
            for i = isCell
            varargin{i} = cellfun(@(x) convertStringsToChars(x), varargin{i},...
                               'UniformOutput', false);
            end
        end
    end
    
    % Get any subsetted dimensions
    info = parseInputs(filename, dims,...
        precision, offset, byteOrder, varargin{:});
    
    % Make sure that the file is large enough for the requested operation
    fileInfo = dir(info.filename);
    fileSize = fileInfo.bytes;
    if fileSize < info.offset + info.dataSize
        error(message('MATLAB:imagesci:multibandread:badFileSize'));
    end
    
    % Take care of the file ordering
    interleave = validatestring(interleave,{'bil','bip','bsq'});
    switch lower(interleave)
        case 'bil'
            readOrder = [2 3 1];
            permOrder = [3 1 2];
        case 'bip'
            readOrder = [3 2 1];
            permOrder = readOrder;
        case 'bsq'
            readOrder = [2 1 3];
            permOrder = readOrder;
    end
    
    % Create a cell array of the dimension indices
    ndx = {info.rowIndex info.colIndex info.bandIndex};
    
    % Decide which reading algorithm to use
    if useMemMappedFile(info.inputClass)
        try
            % Read from a memory mapped file
            im = readMemFile(filename, info, ndx, readOrder);
        catch  %#ok<CTCH>
            % We may not have been able to map the file into memory.
            % In this case, try reading the data directly from the disk.
            info = getDefaultIndices(info, false);
            ndx = {info.rowIndex info.colIndex info.bandIndex};
            im = readDiskFile(filename, info, ndx, readOrder);
        end
        im = permute(im, permOrder);
    elseif strcmpi(interleave, 'bip') && ...
            (isempty(info.subset) || isequal(info.subset, 'b'))
        % Special optimization for BIP cases
        if isempty(info.subset)
            % Read full dataset
            im = readDiskFileBip(filename, info);
        else
            % Read a subset.
            im = readDiskFileBipSubset(filename, info);
        end
    else
        % Use the general-purpose routine.
        im = readDiskFile(filename, info, ndx, readOrder);
        im = permute(im, permOrder);
    end
end
%*****************************************************

function im = readMemFile(filename, info, ndx, readOrder)
    % Memory map the file
    m = memmapfile(filename, 'offset', info.offset, 'repeat', 1, ...
        'format', {info.inputClass info.dims(readOrder) 'x'});
    
    % Permute the indices so that they are in read order
    ndx = ndx(readOrder);
    
    % Do any necessary subsetting.
    im = m.data.x(ndx{1}, ndx{2}, ndx{3});
    
    [~, ~,endian] = computer;
    
    % Change the endianness, if necessary
    if strcmpi(endian, 'l')
        if strcmpi(info.byteOrder, 'ieee-be') || strcmpi(info.byteOrder, 'b')
            im = swapbytes(im);
        end
    else
        if strcmpi(info.byteOrder, 'ieee-le') || strcmpi(info.byteOrder, 'l')
            im = swapbytes(im);
        end
    end
    
    % Change the type of the output, if necessary.
    if ~strcmp(info.inputClass, info.outputClass)
        im = feval(info.outputClass, im);
    end
end
%*****************************************************

function im = readDiskFile(filename, info, srcNdx, readOrder)
    % A general-purpose routine to read from the disk
    % We use fread, which will handle non-integral (bit) types.
    info.fid = fopen(filename, 'r', info.byteOrder);
    lastReadPos = 0;
    skip(info,info.offset,lastReadPos);
    
    % Do permutation of sizes and indices
    srcNdx = srcNdx(readOrder);
    dim = info.dims(readOrder);
    
    % Preallocate image output array
    outputSize = [length(srcNdx{1}), length(srcNdx{2}), length(srcNdx{3})];
    im = zeros(outputSize(1), outputSize(2), outputSize(3), info.outputClass);
    
    % Determine the start and ending read positions
    kStart=srcNdx{1}(1);
    kEnd=srcNdx{1}(end);
    
    % srcNdx is a vector which contains the desired row, column, and band
    % subsets of the input.  destNdx contains the destination in the output
    % matrix.
    destNdx(3) = 1;
    for i=srcNdx{3}
        pos(1) = (i-1)*dim(1)*dim(2);
        destNdx(2) = 1;
        for j=srcNdx{2}
            pos(2) = (j-1)*dim(1);
    
            % Determine what to read
            posStart = pos(1) + pos(2) + kStart;
            posEnd = pos(1) + pos(2) + kEnd;
            readAmt = posEnd - posStart + 1;
    
            % Read the entire dimension
            skipNum = (posStart-1)-lastReadPos;
            if skipNum
                if info.bitPrecision
                    fread(info.fid, skipNum, info.precision);
                else
                    fseek(info.fid, skipNum*info.eltsize, 'cof');
                end
            end
            [data, count] = fread(info.fid, readAmt, info.precision);
            if count ~= readAmt
                msg = ferror(info.fid);
                fclose(info.fid);
                error(message('MATLAB:imagesci:multibandread:readProblem', msg));
            end
            lastReadPos = posEnd;
    
    
            % Assign the specified subset of what was read to the output matrix
            im(:,destNdx(2),destNdx(3)) = data(srcNdx{1}-kStart+1);
            destNdx(2) = destNdx(2) + 1;
        end
        destNdx(3) = destNdx(3) + 1;
    end
    
    fclose(info.fid);
end
%*****************************************************

function im = readDiskFileBip(filename, info)
    % Read a file from disk when no subsetting is requested.  Only a single
    % call to FREAD is necessary.
    info.fid = fopen(filename, 'r', info.byteOrder);
    lastReadPos = 0;
    skip(info,info.offset,lastReadPos);
    
    % extract the dims into meaningful terms
    height = info.dims(1);
    width  = info.dims(2);
    bands  = info.dims(3);
    
    % Read all bands at once.
    im = fread(info.fid,prod(info.dims),['1*' info.precision]);
    im = reshape(im,[bands width height]);
    im = permute(im,[3 2 1]);
    fclose(info.fid);
end
%*****************************************************

function im = readDiskFileBipSubset(filename, info)
    % Read a file from disk, using optimizations applicable to the BIP case
    % when we read bands at a time.
    info.fid = fopen(filename, 'r', info.byteOrder);
    lastReadPos = 0;
    skip(info,info.offset,lastReadPos);
    
    % extract the dims into meaningful terms
    height = info.dims(1);
    width  = info.dims(2);
    bands  = info.dims(3);
    im = zeros(width, height, numel(info.bandIndex), info.outputClass);
    
    % Read the file, one band at a time.
    plane = 1;
    for i=info.bandIndex
        skip(info,info.offset,i-1);
        [data,count] = fread(info.fid, height*width, ...
            ['1*' info.precision], ...
            (bands-1)*info.eltsize);
        if count ~= height*width
            msg = ferror(info.fid);
            fclose(info.fid);
            error(message('MATLAB:imagesci:multibandread:readProblem', msg));
        end
        im(:,:,plane) = reshape(data,size(im(:,:,plane)));
        plane = plane + 1;
    end
    
    im = permute(im,[2 1 3]);
    fclose(info.fid);
end
%*****************************************************

function skip(info,offset,skipSize)
    % Skip to a specified position in the file
    if info.bitPrecision
        fseek(info.fid,offset,'bof');
        fread(info.fid,skipSize,info.precision);
    else
        fseek(info.fid,offset+skipSize*info.eltsize,'bof');
    end
end
%*****************************************************

function info = parseInputs(filename, dims, precision,offset, byteOrder, varargin)
    % Open the file. Determine pixel width and input/output classes.
    fid = fopen(filename,'r',byteOrder);
    if fid == -1
        error(message('MATLAB:imagesci:validate:fileOpen', filename));
    end
    info = getPixelInfo(fid,precision);
    info.filename = fopen(fid);
    fclose(fid);
    
    % Assign sizes
    validateattributes(offset,{'numeric'},{'nonnegative'});
    info.offset = offset;
    
    validateattributes(dims,{'numeric'},{'numel',3});
    info.dims = dims;
    info.byteOrder  = byteOrder;
    
    % Calculate the size of the data
    if info.bitPrecision
        info.dataSize = prod(info.dims) * (info.eltsize/8);
    else
        info.dataSize = prod(info.dims) * info.eltsize;
    end
    
    info.rowIndex  = ':';
    info.colIndex  = ':';
    info.bandIndex = ':';
    bUseMemMap = useMemMappedFile(info.inputClass);
    info = getDefaultIndices(info, bUseMemMap);
    
    % 'subset' is a string with 0-3 characters (r, c, b). The string
    % represents which dimension is being subset
    info.subset = '';
    
    % Analyze the parameters that specify the subset of interest
    if numel(varargin) > 0
        for i=1:length(varargin)
            % Determine the subsetting method
            methods = {'direct', 'range'};
            if length(varargin{i})==2
                %Default to 'Direct'
                method = 'direct';
                n = 2;
            else
                param = varargin{i}{2};
                match = find(strncmpi(param,methods,numel(param)));
                if ~isempty(match)
                    method = methods{match};
                else
                    error(message('MATLAB:imagesci:multibandread:badSubset', param));
                end
                n = 3;
            end
            % Determine the orientation of the subset
            dimensions = {'row', 'column', 'band'};
            param = varargin{i}{1};
            match = find(strncmpi(param,dimensions,numel(param)));
            if ~isempty(match)
                dim = dimensions{match};
            else
                error(message('MATLAB:imagesci:multibandread:unrecognizedDimSubsetString', varargin{ i }{ 1 }));
            end
            % Get the indices for the subset
            info.subset(i) = dimensions{match}(1); %build a string 'rcb'
            switch dim
                case 'row'
                    info.rowIndex = getIndices(method, i, n, varargin{:});
                case 'column'
                    info.colIndex = getIndices(method, i, n, varargin{:});
                case 'band'
                    info.bandIndex = getIndices(method, i, n, varargin{:});
            end
        end
    end
end
%*****************************************************

function ndx = getIndices(method, i, n, varargin)
    % Use a subsetting method
    if strcmp(method,'direct')
        ndx = varargin{i}{n};
    else
        switch length(varargin{i}{n})
            case 2
                ndx = feval('colon',varargin{i}{n}(1),varargin{i}{n}(2)); %#ok<*FVAL>
            case 3
                ndx = feval('colon',varargin{i}{n}(1), ...
                    varargin{i}{n}(2), varargin{i}{n}(3));
            otherwise
                error(message('MATLAB:imagesci:multibandread:badSubsetRange'))
        end
    end
end
%*****************************************************

function info = getPixelInfo(fid, precision)
    % Returns size of each pixel.  Size is in bytes unless precision is
    % bitN or ubitN, in which case width is in bits.
    
    % Determine if precision is bitN or ubitN
    info.bitPrecision = ~isempty(strfind(precision,'bit')); %#ok<*STREMP>
    
    % Reformat the precision string and determine if bit precision is in the
    % shorthand notation
    bitPrecisionWithShorthand = false;
    info.precision = precision(~isspace(precision));
    if strncmp(info.precision(1),'*',1)
        % For bit precision with *source shorthand, set precision to the input
        % precision.  fread will know how to determine the output class, which
        % is the smallest class that can contain the input.
        if info.bitPrecision
            info.precision = precision;
            bitPrecisionWithShorthand = true;
        else
            info.precision(1) = [];
            info.precision = [info.precision '=>' info.precision];
        end
    end
    
    % Determine the input and output types (classes)
    lastInputChar = strfind(info.precision,'=>')-1;
    if isempty(lastInputChar)
        lastInputChar=length(info.precision);
    end
    if bitPrecisionWithShorthand
        info.inputClass = info.precision(2:lastInputChar);
    else
        info.inputClass = precision(1:lastInputChar);
    end
    p = ftell(fid);
    tmp = fread(fid, 1, info.precision);
    info.eltsize = ftell(fid)-p;
    info.outputClass = class(tmp);
    
    % If bit precision with shorthand, set the final precision to the longhand 
    % notation, then parse the precision string to determine eltsize
    if info.bitPrecision
        if bitPrecisionWithShorthand
            info.precision = [info.inputClass '=>' info.outputClass];
        end
        info.eltsize = sscanf(info.inputClass(~isletter(info.inputClass)), '%d');
        if isempty(info.eltsize)
            error(message('MATLAB:imagesci:multibandread:badPrecision', info.precision));
        end
    end
end
%*****************************************************

function info = getDefaultIndices(info, bUseMemMap)
    if ~bUseMemMap
        if ischar(info.rowIndex) && info.rowIndex  == ':'
            info.rowIndex  = 1:info.dims(1);
        end
        if ischar(info.colIndex) && info.colIndex  == ':'
            info.colIndex  = 1:info.dims(2);
        end
        if ischar(info.bandIndex) && info.bandIndex  == ':'
            info.bandIndex  = 1:info.dims(3);
        end
    end
end
%*****************************************************

function rslt = useMemMappedFile(type)
    switch(type)
        case {'int8' 'uint8' 'int16' 'uint16' 'int32' 'uint32' ...
                'int64' 'uint64' 'single' 'double'}
            rslt = true;
        otherwise
            rslt = false;
    end
end
%****************************************************

function wl = set_wl(binning)
% Function for setting the wavelengths, whether binning was used for the capture or not.
    if binning
        wl = [888.47 893.36	898.24 903.13 908.02	912.91	917.8	922.69  927.59	932.49...   % Spectral binning (168 bands)
            937.38	942.28	947.19	952.09	956.99	961.9	966.81	971.72	976.63	981.54...
            986.45	991.37	996.29	1001.21	1006.13	1011.05	1015.97	1020.9	1025.83	1030.76...
            1035.69	1040.62	1045.56	1050.49	1055.43	1060.37	1065.31	1070.24	1075.2	1080.14...
            1085.09	1090.04	1094.98	1099.94	1104.89	1109.85	1114.8	1119.76	1124.72	1129.68...
            1134.65	1139.61	1144.58	1149.55	1154.52	1159.49	1164.46	1169.44	1174.42	1179.4...
            1184.38	1189.36	1194.34	1199.33	1204.31	1209.3	1214.29	1219.28	1224.27	1229.27...
            1234.26	1239.26	1244.26	1249.26	1254.26	1259.27	1264.28	1269.28	1274.29	1279.3...
            1284.32	1289.33	1294.35	1299.37	1304.39	1309.41	1314.43	1319.45	1324.48	1329.5...
            1334.53	1339.56	1344.6	1349.63	1354.66	1359.7	1364.74	1369.78	1374.82	1379.87...
            1384.91	1389.96	1395.01	1400.06	1405.11	1410.16	1415.22	1420.28	1425.34	1430.4...
            1435.46	1440.52	1445.58	1450.65	1455.72	1460.79	1465.86	1470.93	1476.01	1481.08...
            1486.16	1491.24	1496.32	1501.4	1506.49	1511.57	1516.66	1521.75	1526.84	1531.94...
            1537.03	1542.13	1547.23	1552.33	1557.43	1562.53	1567.63	1572.74	1577.84	1582.95...
            1588.06	1593.18	1598.29	1603.4	1608.52	1613.64	1618.76	1623.88	1629.01	1634.13...
            1639.26	1644.39	1649.52	1654.65	1659.79	1664.92	1670.06	1675.2	1680.34	1685.48...
            1690.62	1695.77	1700.91	1706.06	1711.21	1716.36	1721.51	1726.67]';
    else
        wl = [888.21;890.66;893.12;895.57;898.02;900.48;902.93;905.38;907.84;910.29;912.75;... $ No spectral binning (336 bands)
              915.21;917.66;920.12;922.58;925.03;927.49;929.95;932.41;934.87;937.33;939.79;...
              942.25;944.71;947.17;949.63;952.1;954.56;957.02;959.49;961.95;964.41;966.88;...
              969.34;971.81;974.27;976.74;979.21;981.67;984.14;986.61;989.08;991.55;994.02;...
              996.48;998.95;1001.42;1003.9;1006.37;1008.84;1011.31;1013.78;1016.26;1018.73;...
              1021.2;1023.68;1026.15;1028.63;1031.1;1033.58;1036.05;1038.53;1041;1043.48;...
              1045.96;1048.44;1050.92;1053.4;1055.87;1058.35;1060.83;1063.31;1065.8;1068.28;...
              1070.76;1073.24;1075.72;1078.21;1080.69;1083.17;1085.66;1088.14;1090.63;1093.11;...
              1095.6;1098.08;1100.57;1103.06;1105.54;1108.03;1110.52;1113.01;1115.5;1117.99;...
              1120.48;1122.97;1125.46;1127.95;1130.44;1132.93;1135.42;1137.92;1140.41;1142.9;...
              1145.4;1147.89;1150.39;1152.88;1155.38;1157.87;1160.37;1162.87;1165.36;1167.86;...
              1170.36;1172.86;1175.36;1177.86;1180.36;1182.86;1185.36;1187.86;1190.36;1192.86;...
              1195.36;1197.86;1200.37;1202.87;1205.37;1207.88;1210.38;1212.89;1215.39;1217.9;...
              1220.4;1222.91;1225.42;1227.92;1230.43;1232.94;1235.45;1237.96;1240.47;1242.98;...
              1245.49;1248;1250.51;1253.02;1255.53;1258.04;1260.56;1263.07;1265.58;1268.1;...
              1270.61;1273.13;1275.64;1278.16;1280.67;1283.19;1285.7;1288.22;1290.74;1293.26;...
              1295.78;1298.29;1300.81;1303.33;1305.85;1308.37;1310.89;1313.41;1315.94;1318.46;...
              1320.98;1323.5;1326.03;1328.55;1331.07;1333.6;1336.12;1338.65;1341.17;1343.7;...
              1346.23;1348.75;1351.28;1353.81;1356.34;1358.86;1361.39;1363.92;1366.45;1368.98;...
              1371.51;1374.04;1376.57;1379.11;1381.64;1384.17;1386.7;1389.24;1391.77;1394.31;...
              1396.84;1399.37;1401.91;1404.45;1406.98;1409.52;1412.06;1414.59;1417.13;1419.67;...
              1422.21;1424.75;1427.29;1429.83;1432.37;1434.91;1437.45;1439.99;1442.53;1445.07;...
              1447.62;1450.16;1452.70;1455.25;1457.79;1460.34;1462.88;1465.43;1467.97;1470.52;...
              1473.06;1475.61;1478.16;1480.71;1483.26;1485.80;1488.35;1490.90;1493.45;1496;...
              1498.55;1501.11;1503.66;1506.21;1508.76;1511.31;1513.87;1516.42;1518.98;1521.53;...
              1524.09;1526.64;1529.20;1531.75;1534.31;1536.87;1539.42;1541.98;1544.54;1547.10;...
              1549.66;1552.22;1554.78;1557.34;1559.90;1562.46;1565.02;1567.58;1570.14;1572.71;...
              1575.27;1577.83;1580.40;1582.96;1585.52;1588.09;1590.65;1593.22;1595.79;1598.35;...
              1600.92;1603.49;1606.06;1608.62;1611.19;1613.76;1616.33;1618.90;1621.47;1624.04;...
              1626.61;1629.19;1631.76;1634.33;1636.90;1639.48;1642.05;1644.62;1647.20;1649.77;...
              1652.35;1654.92;1657.50;1660.08;1662.65;1665.23;1667.81;1670.39;1672.96;1675.54;...
              1678.12;1680.70;1683.28;1685.86;1688.44;1691.02;1693.61;1696.19;1698.77;1701.35;...
              1703.94;1706.52;1709.10;1711.69;1714.27;1716.86;1719.45;1722.03;1724.62;1727.21;...
              1729.79;1732.38];
    end
end
%****************************************************

function hcube = smooth_hypercube(hcube,span)
% Function for cube smoothing. Significantly slows down performance.
    cube = hcube.DataCube;
    [rows,columns,bands] = size(cube);
    matrix = reshape(cube,rows*columns,bands)';
    f = waitbar(0,'Smothing cube. Please wait...');
    for i = 1:size(matrix,2)
        waitbar(i/size(matrix,2),f,'Smoothing cube. Please wait...')
        matrix(:,i) = smooth(matrix(:,i),span);
    end
    close(f);
    cube = reshape(matrix',rows,columns,bands);
    wl = hcube.Wavelength;
    hcube = hypercube(cube,wl);
end
%****************************************************

function white = set_white(white_reflectance)
% Function for setting the white reflectance.
    switch white_reflectance
        case 'Multi_90'
            white = [0.92891058	0.92853146	0.92813342	0.92775745	0.92749139	0.92730359	0.92712879	0.92707283	0.92694071	0.92713373	0.92733967	...
                0.92777712	0.92809551	0.92827455	0.92823913	0.92806812	0.92767781	0.92706029	0.92682722	0.92667841	0.92653192	0.92641594	...
                0.92588171	0.9257778	0.92563043	0.92557893	0.92541002	0.92561822	0.92575231	0.92530021	0.92526957	0.92507213	0.92511286	...
                0.92504964	0.92484889	0.92475897	0.92441136	0.92478013	0.92470524	0.9245306	0.92431154	0.92451641	0.92444448	0.92437454	...
                0.92387832	0.92335867	0.92309447	0.92300087	0.92248169	0.92165865	0.92107943	0.92074862	0.92057607	0.91993171	0.91928251	...
                0.91875596	0.91793555	0.91697218	0.91628682	0.91617105	0.91661636	0.91691529	0.91717961	0.91771368	0.91839951	0.91879447	...
                0.91925688	0.91972221	0.91986056	0.91975352	0.91990818	0.91983321	0.91993247	0.91968965	0.9200267	0.91985865	0.91972375	...
                0.91979936	0.91966405	0.91960464	0.91945436	0.91910666	0.91906315	0.91900628	0.918829	0.91852764	0.91835191	0.91816266	...
                0.91774855	0.91721534	0.91603173	0.91417423	0.91274295	0.91174316	0.91057956	0.90962943	0.90910735	0.90892971	0.90857953	...
                0.90832117	0.90804433	0.90790804	0.90817698	0.90833822	0.90861221	0.9088174	0.90905208	0.90881235	0.90894708	0.90909427	...
                0.90941396	0.90952793	0.90988324	0.90934589	0.90940678	0.90946352	0.90949645	0.90943026	0.90979355	0.91000574	0.91043861	...
                0.91043798	0.91066621	0.91052526	0.91065494	0.9106457	0.91094852	0.9108935	0.91077942	0.91073163	0.91090011	0.91073701	...
                0.91121728	0.91041792	0.91088834	0.91066344	0.91104441	0.91032381	0.91063618	0.91030402	0.91021441	0.90987306	0.9092441	...
                0.90895227	0.90865702	0.90790102	0.9075948	0.90629207	0.90519459	0.90386539	0.90264633	0.90125646	0.90044123	0.89945278	...
                0.89877116	0.89718461	0.89530697	0.89316885	0.89178588	0.89058847	0.89006385];
        case 'Multi_50'
            white = [0.46121479	0.46112525	0.46083274	0.46066798	0.46050893	0.4603539	0.4601989	0.46009471	0.45996091	0.46007699	0.46008935	...
                0.46030959	0.4604061	0.46047043	0.4603948	0.46026651	0.4599884	0.45976367	0.45959924	0.45927657	0.45917322	0.45905352	...
                0.45888612	0.45874063	0.45859739	0.45840414	0.45832409	0.45835238	0.45835547	0.45807251	0.45802176	0.45779376	0.45769005	...
                0.45757283	0.45739515	0.45728399	0.45703894	0.45714498	0.45696734	0.4568496	0.4566366	0.45669613	0.45662903	0.45649047	...
                0.4562767	0.45607232	0.45597089	0.45591098	0.45579757	0.45555995	0.45534577	0.45519548	0.45517694	0.45503378	0.45490742	...
                0.45482604	0.45469658	0.4545642	0.45436476	0.45419226	0.45408753	0.45387999	0.45361145	0.45351485	0.45336125	0.45319894	...
                0.45300063	0.45303833	0.45281055	0.45262217	0.45247647	0.45231193	0.45226103	0.45181115	0.45186512	0.45169636	0.45158747	...
                0.45141068	0.45127097	0.4511018	0.45090759	0.45067631	0.45055247	0.45043256	0.45027637	0.44999624	0.44985174	0.44973221	...
                0.44959568	0.44933921	0.44893866	0.44839867	0.44799294	0.44776206	0.44757792	0.447343	0.44714529	0.4471408	0.44700679	...
                0.44687665	0.44653403	0.44638832	0.4464493	0.44639918	0.44624944	0.44617749	0.44611974	0.44583143	0.44568828	0.445504	...
                0.44552119	0.445448	0.44526532	0.44484574	0.44476625	0.44472834	0.44460728	0.44446513	0.44451142	0.4444007	0.44445317	...
                0.44416395	0.44406427	0.44379005	0.44386746	0.44354081	0.44357764	0.44335393	0.44318351	0.44302865	0.44303929	0.44283822	...
                0.44294879	0.4425478	0.44272268	0.4425132	0.44263736	0.44219797	0.44230295	0.44211901	0.44202641	0.44183533	0.44163072	...
                0.44154352	0.44132049	0.4412329	0.44131019	0.44084496	0.44076737	0.44047475	0.44039814	0.44016203	0.44011371	0.43981876	...
                0.43973281	0.43945406	0.43953891	0.43904289	0.43902542	0.43888501	0.43892859];
        case 'Multi_20'
            white = [0.21637541	0.2164122	0.21647686	0.2164765	0.21647681	0.21651786	0.21656957	0.2166675	0.21671737	0.21691481	0.21704868	...
                0.21735051	0.2174885	0.21771088	0.21782343	0.21795242	0.21794408	0.21795322	0.21801585	0.21801277	0.21809422	0.21816732	...
                0.21813534	0.21816129	0.21825672	0.21831972	0.21833497	0.21847613	0.21855182	0.21848917	0.21853204	0.21855087	0.21864743	...
                0.21871999	0.21875237	0.21882988	0.2187475	0.21893347	0.2189746	0.21901693	0.21901349	0.21911263	0.21924593	0.2193035	...
                0.21931908	0.21929479	0.21936772	0.21948558	0.21950157	0.21951093	0.21953813	0.21957564	0.21963678	0.21970801	0.21975798	...
                0.2198568	0.21990405	0.21995792	0.21997301	0.22002693	0.22009325	0.22010201	0.22014511	0.22019791	0.22026536	0.22029846	...
                0.22031392	0.22043015	0.22046257	0.22046401	0.22047315	0.22056162	0.22062197	0.22060743	0.22074568	0.2207578	0.22082614	...
                0.22081981	0.22088718	0.22095384	0.22095909	0.2209688	0.22102308	0.2211066	0.22113888	0.2211717	0.22125183	0.22125752	...
                0.221288	0.22129726	0.22121281	0.22112632	0.22105041	0.22113549	0.22110478	0.22108967	0.22112294	0.22122964	0.22131019	...
                0.22131466	0.22128111	0.22130927	0.22143659	0.22153892	0.22163689	0.22169234	0.2217366	0.22179491	0.22179328	0.22185784	...
                0.22196125	0.22196775	0.22207944	0.22200448	0.22207926	0.22218809	0.2222435	0.22225214	0.22236842	0.22245498	0.22256545	...
                0.22254227	0.22265935	0.22266063	0.22275875	0.22277176	0.22292632	0.22293908	0.22294699	0.22300896	0.22314495	0.22317062	...
                0.22331589	0.22320143	0.22338996	0.22340953	0.22360929	0.2235218	0.22368661	0.22355374	0.22367531	0.22376273	0.22376669	...
                0.22380431	0.22391488	0.22385374	0.22400036	0.22386707	0.22396823	0.2238442	0.22402565	0.22396722	0.22399979	0.22393134	...
                0.22402281	0.22396677	0.22404237	0.22398554	0.22407453	0.22410575	0.22420657];
        case 'Multi_5'
            white = [0.05356469	0.05357274	0.05355923	0.05353791	0.05358429	0.05353057	0.05353643	0.05353455	0.05352414	0.05355117	0.05352362	...
                0.05361908	0.05367278	0.05367195	0.05360688	0.05363294	0.05361899	0.05359309	0.05357562	0.05357617	0.05356083	0.05352606	...
                0.05351403	0.0535361	0.05349038	0.05350367	0.05351697	0.05354405	0.05355309	0.05355658	0.05353775	0.05356121	0.0535582	...
                0.05353375	0.05356935	0.05357134	0.05353639	0.05359707	0.05357828	0.05358607	0.05358145	0.05358228	0.05358381	0.053657	...
                0.05358048	0.05357345	0.05357445	0.05365881	0.05361513	0.05363177	0.05363641	0.05360902	0.05362527	0.05366248	0.05364313	...
                0.05367116	0.0536689	0.05367364	0.0536614	0.05366728	0.05367215	0.05366826	0.05368587	0.05368321	0.05368909	0.05366176	...
                0.05367981	0.0537209	0.05366328	0.05370421	0.05368499	0.0537398	0.05368391	0.05367311	0.05370932	0.0537099	0.05370019	...
                0.05369071	0.05369617	0.05368536	0.05372086	0.05368002	0.0536962	0.05369729	0.05372551	0.05369775	0.0537081	0.0537208	...
                0.05370334	0.05371899	0.05366328	0.05366312	0.05363044	0.05361142	0.05364277	0.05361731	0.05357955	0.05359586	0.05359621	...
                0.05363652	0.05361437	0.05360183	0.053636	0.05362866	0.05362192	0.05367127	0.05370212	0.05367102	0.05366377	0.05364015	...
                0.05365721	0.05367622	0.05367883	0.05366105	0.05369611	0.0537123	0.05369459	0.0536846	0.05375168	0.05368684	0.05375516	...
                0.05372033	0.05373778	0.05372032	0.05380733	0.05377197	0.05376977	0.05380121	0.05378301	0.0538096	0.05383401	0.05380588	...
                0.05384491	0.05382071	0.05387532	0.05381069	0.05390708	0.05386846	0.05392873	0.05385385	0.05387295	0.05389697	0.05390865	...
                0.05398791	0.05390419	0.05394174	0.05396546	0.05391149	0.05392557	0.05390652	0.0539419	0.05397516	0.05398884	0.05391003	...
                0.05397643	0.05393741	0.05400747	0.05397145	0.05400109	0.05392235	0.05393261];
        case 'Sphere'
            white = [0.954243711	0.954473694	0.954251229	0.954319003	0.953149578	0.953830391	0.954144247	0.952682436	0.952286762	0.951463272	...
                0.953442102	0.953166861	0.953764183	0.954412284	0.954911115	0.954585061	0.953632613	0.953157611	0.952663184	0.953886361	0.952647126	...
                0.952471756	0.953995052	0.953212671	0.953619941	0.951692631	0.953905675	0.95329714	0.952920887	0.953482601	0.953900448	0.952032036	...
                0.952919561	0.953640082	0.952361354	0.952357641	0.952538174	0.952895367	0.951921605	0.95236421	0.952243036	0.953203201	0.951384072	...
                0.95168803	0.951352231	0.95072109	0.951450042	0.95156675	0.951449627	0.950663528	0.950135733	0.949575653	0.949123971	0.95012695	...
                0.949646764	0.949274115	0.9483701	0.947946254	0.948503498	0.94830805	0.948144164	0.948331618	0.947007886	0.949559773	0.94931648	...
                0.94887791	0.94975085	0.949014978	0.949066089	0.949300122	0.948697127	0.949661936	0.948577569	0.948955229	0.948767049	0.948513349	...
                0.949156266	0.94948897	0.949437147	0.948912276	0.948245367	0.949195109	0.948645656	0.949201479	0.947631724	0.947870285	0.947913149	...
                0.947140067	0.94697112	0.946642959	0.946068818	0.944760628	0.944029966	0.94443915	0.943995456	0.941917009	0.942330788	0.941798968	...
                0.942175568	0.941482913	0.940617607	0.941097291	0.940776948	0.939956458	0.941029146	0.940447427	0.939727416	0.940473964	0.941392234	...
                0.94137777	0.939439856	0.9409455	0.941038943	0.940892724	0.940293499	0.94094348	0.941339445	0.941678414	0.941058194	0.941697412	...
                0.940951704	0.942684561	0.941437827	0.941536028	0.941805208	0.942167206	0.941896647	0.941462599	0.941768031	0.942508324	0.94194726	...
                0.941460141	0.940910223	0.942349398	0.941740643	0.942586356	0.941915772	0.941521866	0.94160468	0.941591372	0.940824202	0.942218525	...
                0.941978768	0.941167186	0.939892865	0.940279547	0.939543722	0.939606098	0.93810747	0.938182676	0.938247308	0.936919922	0.936218062	...
                0.93683075	0.934330918	0.934868651	0.932817729	0.932800173	0.932256022	0.931414779	0.93211606];
        case 'Teflon'
            white = [0.847218883	0.84598857	0.844766346	0.843552831	0.842356863	0.841189274	0.840059534	0.838971644	0.837923122	0.836900485	...
                0.835893528	0.834894409	0.83389803	0.832901278	0.831901118	0.830891794	0.829862327	0.828799894	0.827690252	0.826517996	0.825275294	...
                0.823963905	0.822587139	0.821149165	0.819664038	0.818148405	0.81661842	0.815089446	0.813571604	0.812068673	0.810581776	0.809111484	...
                0.807652656	0.806195872	0.804725326	0.803214467	0.801641377	0.799986484	0.798233789	0.796368478	0.794394259	0.792310335	0.790115649	...
                0.787815149	0.785430599	0.782983504	0.780497603	0.777996638	0.775494426	0.772994793	0.77049369	0.767978908	0.765434591	0.762845563	...
                0.760205133	0.757543794	0.754925914	0.752439369	0.750198979	0.748254698	0.746608547	0.745223073	0.744044688	0.74298561	0.741994725	...
                0.741035671	0.740083525	0.739124943	0.738156504	0.737180627	0.736204204	0.735233264	0.734268702	0.733303841	0.732322007	0.731305386	...
                0.730239188	0.729110771	0.727911827	0.726630501	0.725242674	0.723709411	0.722013304	0.720165376	0.71819639	0.716150205	0.714077148	...
                0.712002973	0.709937187	0.707881088	0.705833643	0.703796613	0.701772139	0.699760619	0.697756325	0.695751347	0.69373401	0.691685671	...
                0.689588919	0.68742711	0.685187163	0.682867121	0.680482936	0.678051255	0.675588797	0.673110811	0.670626398	0.668139615	0.665652331	...
                0.663165799	0.660682325	0.658207085	0.655751868	0.653331801	0.650959295	0.648638323	0.646358336	0.644085952	0.641792107	0.639463157	...
                0.637111603	0.634777104	0.632496071	0.630292415	0.62817176	0.626110757	0.624088304	0.622086758	0.620095026	0.618109649	0.616133031	...
                0.614170839	0.612227464	0.610298217	0.608369449	0.606417385	0.604418358	0.602364722	0.600260789	0.59811523	0.595932427	0.593701158	...
                0.591402158	0.58901582	0.586553704	0.584041154	0.581507152	0.578976601	0.576459878	0.573956531	0.571462309	0.568972758	0.566485079	...
                0.563999583	0.561520182	0.5590592	0.556637202	0.554284208	0.552039302	0.549938075	0.547981534];
        otherwise
            white = white_reflectance;
    end
end