function Process_cubes_PikaL(mode,stage,white_reflectance, crop, rotate, imageband, meta, binning,smoo)

% This code reads the hyperspectral data from spectral cubes captured with
% Resonon PikaL and Spectronon software. Please be sure to store in the
% same folder the files '.bil' (or '.bip' or '.bsq'), and their corresponding
% files (with the same name) '.hdr' containing metadata. This script
% processes all full cubes in the selected folder. Giving the option for
% manual crop, rotation and/or vertical or horizontal flip.
% The code assumes that, if captured on the linear stage (stage = linear)
% the white reference used for the flat field has a known spectral reflectance contained in white_reflectance.
% Use 'teflon_white_reflectance_PikaL.mat' file for teflon bar. Otherwise, if captured in the rotating tripod
% (stage = angular) no correction is performed to account for the white reference reflectance.
% If imageband is set different from 0, a '.png' image file is created with
% the selected bands as grayscale image or as false RGB image.
% The final c1ube is stored as a MATLAB Hypercube object.

% Example usage: Process_cubes_PikaL('ref','linear','Multi_90', true, true, [50 34 9], false, true,0);
%
% For a false RGB display of the resulting cubes type: imshow(cube.DataCube(:,:,[50 34 9]),[])
%
% INPUTS:   mode                [char]      -> 'raw', 'rad', 'ref. Capturing mode: raw, radiance or reflectance.
%           stage               [char]      -> 'linear': if captured in linear stage.
%                                           -> 'angular': if captured in rotating tripod.
%           white_reflectance   [char]      -> 'Multi_90', 'Multi_50', 'Multi_20', 'Multi_5', 'Sphere', 'Teflon'.
%                               [121 x 1]   ->  Otherwise Spectral reflectance of the reference white tile used for flat field correction.
%                                              when capturing on the linear stage. Only used if stage == 'linear'.
%           crop                [bool]      -> if 'true', the cubes will be cropped.
%           rotate              [bool]      -> if 'true', the cubes will be rotated or flipped.
%           imageband           [integer]   -> if set to integer value different from 0, a '.png' image of the selected band is created in grayscale.
%                               [triplet]   -> if set to a triplet of integer values, a '.png' image of a false RGB is crated with the three selected bands.
%           meta                [bool]      -> if true, the script allows to input and store metadata for each cube. Otherwise it does not.
%           binning             [bool]      -> if true, it assumes spectral binning is on during capture (150 bands). Otherwise assumes no binning during capture (300 bands).
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
        wl_new = (400:5:1000)';
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
        tline = fgets(fileID);
        header_offset = str2double(tline(17));
        fclose(fileID);
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
        cube = interp_cube(wl,cube,wl_new); % Interpolate cube to 5 nm wavlength range.
        if strcmp(mode,'ref')
            % Setting of white reflectance
            white = set_white(white_reflectance);
            cube = cube .* repmat(reshape(white,1,1,length(white)),size(cube,1),size(cube,2));
        end
        close all;

        % Cropping cube, if crop == true
        if crop == 1
            cube = cropint_PikaL_cube(cube); % After cropping press enter.
        end

        % Rotation of the cube, if selected.
        if rotate == 1
            im = cat(3,imadjust(cube(:,:,42)),imadjust(cube(:,:,28)),imadjust(cube(:,:,7)));
            figure, imshow(im,[]);
            clc, disp(['Processing cube ' num2str(i) ' of ' num2str(length(d)) '...'])
            prompt = {'\fontsize{15} Enter rotation angle in degrees (negative angles rotate clockwise):','\fontsize{15} Enter Left-Right flip flag (1 = true or 0 = false):','\fontsize{15} Enter Up-Down flip flag (1 = true or 0 = false)'};
            dlgtitle = 'Rotation / flip data';
            dims = [2 100];
            definput = {'90','0','0'};
            opts.Resize = 'on';
            opts.Interpreter = 'tex';
            answer = inputdlg(prompt,dlgtitle,dims,definput,opts);
            cube = rotate_flip_Lint(cube,str2double(answer{1}),str2double(answer{2}),str2double(answer{3}));
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
                % False RGB.
                im_cube = cat(3,imadjust(cube(:,:,imageband(1))),imadjust(cube(:,:,imageband(2))),imadjust(cube(:,:,imageband(3))));
            else
                % Grayscale.
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
                definput = {'0','This cube contains ...','0','Hallogen','Teflon','XV','No','0','Paper','0','None'};
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
            Metadata.wl = [false; true; false];         % Spectral range, [UVIS; VNIR; SWIR].
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
            Metadata.device = 'PikaL';                  % Device used for the capture.
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
            save([filename(1:end-3) 'mat'],'cube','wl','texp','stage','mode','-v7.3')
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

%% Now the auxiliary functions are delcared:

function cube = interp_cube(wl,cube,wl_new)
% Function for cube interpolation into the final wavelength range.
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

function croped_cube = cropint_PikaL_cube(cube)
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
            imshow(cat(3,imadjust(croped_cube(:,:,50)),imadjust(croped_cube(:,:,34)),imadjust(croped_cube(:,:,9))),[])
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

function cuber = rotate_flip_Lint(cube, angle, LR,UP)
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
% Function for reading the .bil, .bip or .bsq files

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
%*****************************************************

function wl = set_wl(binning)
% Function for setting the wavelengths, whether binning was used for the capture or not.
    if binning
        wl = [383.95;387.97;391.98;396;400.02;404.05;408.08;412.11;416.14;420.18;424.22;428.26;432.31;... % Spectral binning (150 bands).
          436.36;440.42;444.47;448.53;452.59;456.66;460.73;464.8;468.88;472.95;477.04;481.12;485.21;...
          489.3;493.39;497.49;501.59;505.69;509.8;513.91;518.02;522.14;526.26;530.38;534.51;538.63;...
          542.77;546.9;551.04;555.18;559.32;563.47;567.62;571.78;575.93;580.09;584.26;588.42;592.59;...
          596.76;600.94;605.12;609.3;613.48;617.67;621.86;626.06;630.26;634.46;638.66;642.87;...
          647.08;651.29;655.51;659.73;663.95;668.17;672.4;676.63;680.87;685.11;689.35;693.59;697.84;...
          702.09;706.35;710.6;714.86;719.13;723.39;727.66;731.93;736.21;740.49;744.77;749.06;753.34;...
          757.64;761.93;766.23;770.53;774.83;779.14;783.45;787.76;792.08;796.4;800.72;805.05;...
          809.38;813.71;818.05;822.38;826.73;831.07;835.42;839.77;844.12;848.48;852.84;857.2;861.57;...
          865.94;870.31;874.69;879.07;883.45;887.84;892.23;896.62;901.01;905.41;909.81;914.22;...
          918.62;923.03;927.45;931.86;936.28;940.71;945.13;949.56;953.99;958.43;962.87;967.31;971.76;...
          976.2;980.66;985.11;989.57;994.03;998.49;1002.96;1007.43;1011.9;1016.38];
    else
        wl = [383.95;385.96;387.97;389.97;391.98;393.99;396;398.01;400.02;402.03;404.05;406.06;408.08;...   % No binning (30 bands).
            410.09;412.11;414.12;416.14;418.16;420.18;422.2;424.22;426.24;428.26;430.29;432.31;434.34;...
            436.36;438.39;440.42;442.44;444.47;446.5;448.53;450.56;452.59;454.63;456.66;458.69;460.73;...
            462.76;464.8;466.84;468.88;470.91;472.95;474.99;477.04;479.08;481.12;483.16;485.21;487.25;...
            489.3;491.35;493.39;495.44;497.49;499.54;501.59;503.64;505.69;507.75;509.8;511.86;513.91;...
            515.97;518.02;520.08;522.14;524.2;526.26;528.32;530.38;532.44;534.51;536.57;538.63;540.7;...
            542.77;544.83;546.9;548.97;551.04;553.11;555.18;557.25;559.32;561.4;563.47;565.55;567.62;...
            569.7;571.78;573.85;575.93;578.01;580.09;582.17;584.26;586.34;588.42;590.51;592.59;594.68;...
            596.76;598.85;600.94;603.03;605.12;607.21;609.3;611.39;613.48;615.58;617.67;619.77;621.86;...
            623.96;626.06;628.16;630.26;632.36;634.46;636.56;638.66;640.76;642.87;644.97;647.08;649.18;...
            651.29;653.4;655.51;657.62;659.73;661.84;663.95;666.06;668.17;670.29;672.4;674.52;676.63;...
            678.75;680.87;682.99;685.11;687.23;689.35;691.47;693.59;695.72;697.84;699.97;702.09;704.22;...
            706.35;708.47;710.6;712.73;714.86;716.99;719.13;721.26;723.39;725.53;727.66;729.8;731.93;...
            734.07;736.21;738.35;740.49;742.63;744.77;746.91;749.06;751.2;753.34;755.49;757.64;759.78;...
            761.93;764.08;766.23;768.38;770.53;772.68;774.83;776.99;779.14;781.3;783.45;785.61;787.76;...
            789.92;792.08;794.24;796.4;798.56;800.72;802.89;805.05;807.21;809.38;811.54;813.71;815.88;...
            818.05;820.21;822.38;824.55;826.73;828.9;831.07;833.24;835.42;837.59;839.77;841.95;844.12;...
            846.3;848.48;850.66;852.84;855.02;857.2;859.39;861.57;863.76;865.94;868.13;870.31;872.5;...
            874.69;876.88;879.07;881.26;883.45;885.64;887.84;890.03;892.23;894.42;896.62;898.81;901.01;...
            903.21;905.41;907.61;909.81;912.01;914.22;916.42;918.62;920.83;923.03;925.24;927.45;929.66;...
            931.86;934.07;936.28;938.49;940.71;942.92;945.13;947.35;949.56;951.78;953.99;956.21;958.43;...
            960.65;962.87;965.09;967.31;969.53;971.76;973.98;976.2;978.43;980.66;982.88;985.11;987.34;...
            989.57;991.8;994.03;996.26;998.49;1000.72;1002.96;1005.19;1007.43;1009.66;1011.9;1014.14;...
            1016.38;1018.62];
    end
end
%*****************************************************

function hcube = smooth_hypercube(hcube,span)
% Function for cube smoothing. Significantly slows down performace.
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
%*****************************************************

function white = set_white(white_reflectance)
% Function for setting the white reflectance.
    switch white_reflectance
        case 'Multi_90'
            white = [0.94332739;0.94272599;0.9429587;0.94392938;0.94453078;0.9460848;0.94527088;0.94428336;0.94475201;0.94535213;0.94555955;...
                     0.94542305;0.94484793;0.94437511;0.94459751;0.94418216;0.94478368;0.94471024;0.94471005;0.94466565;0.94419501;0.94424115;...
                     0.94408467;0.9440786;0.94401017;0.94374275;0.9433519;0.94327987;0.94313649;0.94317241;0.94249733;0.94219909;0.94150077;...
                     0.94181476;0.94195696;0.94125809;0.94139837;0.94186997;0.94073934;0.94099113;0.94055914;0.94057246;0.9403842;0.9401759;...
                     0.93898701;0.93962702;0.93902978;0.93941681;0.93915889;0.93888463;0.93859995;0.93823624;0.93789211;0.93680851;0.93830738;...
                     0.93716315;0.93774751;0.93801031;0.9367933;0.93770679;0.93520652;0.93568712;0.93417627;0.93695163;0.93623721;0.93590096;...
                     0.93408144;0.93555625;0.93310126;0.93463823;0.93559375;0.93420273;0.93398872;0.93368243;0.93353137;0.93361078;0.93498727;...
                     0.93194868;0.93313056;0.93236357;0.93084149;0.93370888;0.9336859;0.9324003;0.93209391;0.93205331;0.93176808;0.93120433;...
                     0.93138241;0.93124549;0.93076765;0.93065353;0.93091487;0.93066122;0.93003477;0.92994038;0.9299958;0.92977902;0.92961441;...
                     0.92941555;0.92891058;0.92853146;0.92813342;0.92775745;0.92749139;0.92730359;0.92712879;0.92707283;0.92694071;0.92713373;...
                     0.92733967;0.92777712;0.92809551;0.92827455;0.92823913;0.92806812;0.92767781;0.92706029;0.92682722;0.92667841;0.92653192];
        case 'Multi_50'
            white = [0.46736892	0.46685422	0.46647415	0.46682961	0.46697487	0.46733659	0.46685755	0.46654177	0.46682085	0.46705577	...
                0.4673019	0.46725241	0.46707747	0.46717142	0.46727374	0.4671495	0.46728773	0.46754304	0.46760767	0.46765941	...
                0.46758285	0.46786853	0.46793148	0.46808321	0.46818812	0.46802307	0.46788282	0.46802407	0.46790166	0.46805623	...
                0.46789951	0.46783813	0.46772151	0.46777748	0.46786772	0.46755084	0.46763466	0.46806967	0.46762315	0.46776454	...
                0.46755818	0.4677134	0.46739751	0.46760087	0.46733749	0.46759611	0.46686286	0.46709097	0.46718996	0.46708498	...
                0.46687323	0.46675459	0.46672407	0.46628402	0.46705108	0.46671129	0.46637221	0.46686794	0.4666536	0.46685049	...
                0.46548041	0.46612975	0.46453376	0.46661001	0.46634287	0.46551793	0.46602229	0.46573882	0.4636831	0.46556097	...
                0.46669917	0.46532979	0.46458038	0.46463455	0.46434963	0.46466226	0.46523238	0.46414249	0.46435568	0.46472262	...
                0.46401024	0.46453781	0.46414578	0.46277179	0.46381574	0.46292089	0.46279046	0.46239256	0.46261077	0.46247429	...
                0.46219356	0.4621544	0.46220394	0.4620993	0.4618824	0.46182959	0.46182529	0.46174046	0.46155499	0.46151616	...
                0.46121479	0.46112525	0.46083274	0.46066798	0.46050893	0.4603539	0.4601989	0.46009471	0.45996091	0.46007699	...
                0.46008935	0.46030959	0.4604061	0.46047043	0.4603948	0.46026651	0.4599884	0.45976367	0.45959924	0.45927657 0.45917322];
        case 'Multi_20'
            white = [0.21028306	0.20981019	0.20964433	0.20972398	0.20979658	0.20990952	0.20966362	0.20957661	0.20978402	0.20987631...
            	0.2100352	0.21000153	0.20972609	0.20969174	0.20979172	0.2098454	0.21021618	0.21032558	0.21051733	0.21056008	...
                0.2103828	0.21052186	0.21052556	0.21074624	0.21077597	0.21077484	0.21093133	0.21108845	0.21122852	0.21131883	...
                0.21120423	0.21137677	0.21157519	0.21161144	0.21168401	0.21174482	0.21197004	0.21215179	0.21207316	0.21227756	...
                0.21242335	0.2124583	0.21251601	0.21264572	0.21252814	0.21263846	0.21264341	0.21273616	0.21285031	0.21300244	...
                0.21302917	0.2132191	0.21321852	0.21309248	0.21348334	0.21341592	0.21332419	0.21344195	0.21353372	0.21365211	...
                0.21365761	0.21390162	0.21338438	0.21406791	0.21419747	0.21402791	0.21428453	0.21419711	0.21341569	0.21432375	...
                0.21447735	0.21466124	0.21433336	0.21400193	0.21431947	0.21426312	0.21481707	0.21443041	0.2150735	0.21463276	...
                0.21501833	0.21514307	0.21522952	0.21580519	0.21569307	0.21596642	0.2156953	0.21589581	0.21595971	0.2160299	...
                0.21614013	0.21613428	0.21623479	0.21639181	0.21616453	0.21629745	0.21631139	0.21625519	0.21645134	0.21648566	...
                0.21637541	0.2164122	0.21647686	0.2164765	0.21647681	0.21651786	0.21656957	0.2166675	0.21671737	0.21691481	...
                0.21704868	0.21735051	0.2174885	0.21771088	0.21782343	0.21795242	0.21794408	0.21795322	0.21801585	0.21801277	0.21809422];
        case 'Multi_5'
            white = [0.05508688	0.05496392	0.05488017	0.05472607	0.05477159	0.05474116	0.05458616	0.05452788	0.0545308	0.05449468...
            	0.05445831	0.0545173	0.05444861	0.05440789	0.05440832	0.05430464	0.05428624	0.05425417	0.05414626	0.05419017	...
                0.05418609	0.05431517	0.05426087	0.05421678	0.05420416	0.05415117	0.05411587	0.05411848	0.0541009	0.05409916	...
                0.05410793	0.05397056	0.05398327	0.05394388	0.05399287	0.05397952	0.05398466	0.05396197	0.05389377	0.05393616	...
                0.05389164	0.05387357	0.05394144	0.05387318	0.0538686	0.05389293	0.05384927	0.05389825	0.05381367	0.05384674	...
                0.05385136	0.053834	0.05385769	0.05371137	0.05378497	0.05378589	0.0538279	0.053885	0.05371464	0.05380113	...
                0.05366965	0.05364658	0.05362681	0.05371396	0.05381123	0.05381967	0.05373976	0.05368556	0.05349006	0.05369128	...
                0.0537186	0.05387582	0.05379846	0.05384944	0.05377229	0.05383468	0.05371257	0.05358403	0.05355925	0.05365518	...
                0.05364144	0.05379475	0.05369964	0.05352896	0.05370551	0.05359634	0.05363502	0.05379504	0.05359371	0.05355365	...
                0.05358214	0.05365136	0.05361882	0.05358399	0.05358101	0.05356126	0.05357104	0.05360619	0.05364642	0.05350322	...
                0.05356469	0.05357274	0.05355923	0.05353791	0.05358429	0.05353057	0.05353643	0.05353455	0.05352414	0.05355117	...
                0.05352362	0.05361908	0.05367278	0.05367195	0.05360688	0.05363294	0.05361899	0.05359309	0.05357562	0.05357617	0.05356083];
        case 'Sphere'
            white = [0.960599383	0.9609256	0.961028389	0.961877505	0.962731308	0.961345253	0.962031665	0.962150235	0.962083567	0.962028632...
            	0.963150543	0.962814128	0.962838422	0.961651649	0.962123578	0.961902122	0.962389321	0.962731104	0.96329551	0.9628507	...
                0.963241792	0.963300743	0.96246817	0.96264643	0.962642559	0.963225649	0.962967955	0.96289269	0.962718891	0.962900085	...
                0.96242633	0.962036005	0.963065564	0.962051236	0.961724487	0.962359757	0.962979661	0.962646256	0.962769718	0.961842068	...
                0.961328679	0.961485495	0.961769188	0.961633597	0.961465177	0.960436792	0.961024665	0.960919802	0.960542435	0.960423501	...
                0.960495667	0.960736413	0.961152683	0.960007047	0.960097967	0.960223025	0.959792609	0.959790069	0.959917802	0.958963277	...
                0.959323239	0.959354969	0.958918485	0.959589254	0.958639338	0.958663731	0.958405348	0.958188806	0.959078955	0.957551065	...
                0.958083595	0.957446198	0.95812442	0.958082656	0.957644913	0.957879856	0.958334732	0.957861657	0.958232347	0.957310135	...
                0.957038733	0.956768378	0.958172992	0.956655062	0.956019287	0.957288781	0.957227206	0.957723345	0.956429031	0.953723154	...
                0.953858537	0.954301108	0.954340443	0.955405888	0.957776075	0.955598902	0.955816785	0.955619205	0.956898071	0.956441976	...
                0.954119402	0.95421485	0.953507967	0.953801084	0.953528912	0.95267743	0.953648532	0.951947822	0.951812333	0.951371723	...
                0.953287517	0.952999019	0.95403858	0.95463632	0.954949487	0.954456189	0.954709945	0.953557373	0.952600059	0.953640685	0.9518383];
        case 'Teflon'
            white = [0.933550272	0.933978337	0.93416985	0.934121503	0.9338635	0.933455841	0.932956439	0.93241854	0.931880007	...
                0.931351703	0.930829264	0.93029857	0.929743198	0.929152484	0.928523942	0.92786578	0.927202005	0.926556615	0.925951668	...
                0.92541105	0.92494052	0.924539406	0.924194737	0.923877925	0.923552389	0.92319354	0.922789371	0.922343176	0.921869937	...
                0.921380585	0.920881043	0.920370552	0.919843283	0.91929091	0.918704799	0.918084716	0.917440687	0.916789219	0.91615601	...
                0.915569954	0.915052021	0.914611941	0.914244831	0.913915731	0.913588234	0.913232919	0.912831036	0.912389062	0.911918579	...
                0.911431733	0.91093828	0.91044574	0.909960551	0.909491318	0.90904861	0.908632193	0.908227241	0.907795677	0.907271945	...
                0.892243841	0.890731888	0.889257234	0.887818777	0.886417106	0.885043066	0.88368535	0.882330831	0.88096531	0.879578779	...
                0.878161608	0.876702034	0.875185089	0.873610221	0.871985049	0.870328523	0.868670119	0.867034533	0.865434845	0.863874626	...
                0.862347028	0.860842043	0.859354975	0.857887398	0.85644491	0.855032844	0.853654978	0.852313603	0.85100413	0.849721396	...
                0.84846095	0.847218883	0.84598857	0.844766346	0.843552831	0.842356863	0.841189274	0.840059534	0.838971644	0.837923122	...
                0.836900485	0.835893528	0.834894409	0.83389803	0.832901278	0.831901118	0.830891794	0.829862327	0.828799894	0.827690252	...
                0.826517996	0.825275294];
        otherwise
            white = white_reflectance;
    end
end