% % % change shading layer into gray, all color is in albedo layer

clear all;
close all;

DataSet = 'MPI';

DataDir = ['../datasets/',DataSet,'/'];
DumpDir = ['../datasets/', DataSet, '/temp_refine_2/'];
OutDir = ['../datasets/', DataSet, '/refined/'];
OutDir_new = ['../datasets/', DataSet, '/refined_gs/'];

MaskDir = [DataDir, 'MPI-main-mask/'];
InputDir = [OutDir, 'MPI-main-clean/'];
AlbedoDir = [OutDir, 'MPI-main-albedo/'];
ShadingDir = [OutDir, 'MPI-main-shading/'];
file_lists = dir([ShadingDir, '*.png']);

for n = 1:length(file_lists)
    gap = 6.0;
    threshold = 0.985;
    scale_factor1 = 1.5;
    scale_factor2 = 1.5;
    lle_flag = false;
    if n > 200 && n <= 300  % bandage
        threshold = 0.98;
        scale_factor2 = 6.7;
    elseif n > 300 && n <= 400  % cave, girl slash dragon
        threshold = 0.98;
        gap = 7.0;
        scale_factor1 = 3.5;    % 401 ~ 450, market_2, 451 ~ 500
    elseif n > 540 && n <= 590  % mountain
        lle_flag = false;
    elseif n > 590 && n <= 640
        threshold = 0.95;
    elseif n > 640 && n <= 690  % grase and stample
        threshold = 0.98;
        scale_factor2 = 6.5;
    elseif n > 690 && n <= 740  % sleeping 1
        threshold = 0.955;
        scale_factor1 = 5.5;
    elseif n > 741 && n <= 790  % sleeping 2
        threshold = 0.975;
        scale_factor2 = 2.5;
    elseif n > 790 && n <= 840  % temple 2
        scale_factor1 = 1.5;
        threshold = 0.985;
    else
    end
 
    frame_name = file_lists(n).name;
    albedoName = [AlbedoDir frame_name];
    shadingName = [ShadingDir frame_name];
    maskName = [MaskDir frame_name];
    inputName = [InputDir frame_name];
    
    disp(['...Processing: ', num2str(n), '; FileName: ', frame_name]);

    input = im2double(imread(inputName));
    albedo = im2double(imread(albedoName));
    shading = im2double(imread(shadingName));
    [height, width, channel] = size(albedo);
    maskimg = repmat(imresize(imread(maskName), [height, width], 'nearest'),[1,1,3]);
    valid_idx = maskimg == 255;
    
    %% simple assumption: I = A.*S
    albedo(albedo == 0) = 0.01;  % eleminate absolute zeros
    input_rec = albedo .* shading;
    albedo_rec = input ./ (shading);
    shading_rec = input ./ (albedo);

    %% L*a*b* color space
    input_lab = rgb2lab(input);
    albedo_lab = rgb2lab(albedo);
    shading_lab = rgb2lab(shading);
    input_rec_lab = rgb2lab(input_rec);
    albedo_rec_lab = rgb2lab(albedo_rec);
    shading_rec_lab = rgb2lab(shading_rec);
    
    L_i = input_lab(:,:,1);  % the Luminance channel, [0,100]
    L_a = albedo_lab(:,:,1);
    L_s = shading_lab(:,:,1);
    L_i_rec = input_rec_lab(:,:,1);
    L_a_rec = albedo_rec_lab(:,:,1);
    L_s_rec = shading_rec_lab(:,:,1);
    
    % get validate pixels in L_albedo_rec
    a_valid_mask = L_a_rec < 100;  % use this as valid
    s_valid_mask = L_s_rec < 95;   % [95] or use this. more strict
    
    % get the statistics of albedo
%     L_arec_valid = L_a_rec(a_valid_mask);
    L_arec_valid = L_a_rec(s_valid_mask & a_valid_mask);
    mu_arec = mean(L_arec_valid);
    std_arec = std(L_arec_valid);
    
    mu_a = mean(L_a(:));
    std_a = std(L_a(:));
    mu_s = mean(L_s(:));
    std_s = std(L_s(:));

    %% rec type 2
    albedo_new = albedo;
    L_s(L_s == 0) = 0.03;
    shading_new = repmat(L_s / 100, [1,1,3]);
    input_new = albedo_new .* shading_new;
    input_new(input_new == 0) = 0.013;

    if sum(L_s(:) == 0) > 0
        disp('Warning! shading has zero values!')
        figure(1), imshow([input_new; albedo_new; shading_new])
        figure(2), imshow([albedo, input_new ./ shading_new; shading, input_new ./ albedo_new])
    end
    
    albedo_invalid_mask = albedo(:,:,1)==0 | albedo(:,:,2)==0 | albedo(:,:,3)==0;
    if sum(albedo_invalid_mask(:))
        disp('Warning! albedo has zero values!')
        figure(3), imshow(albedo_invalid_mask)
    end
    
    input_invalid_mask = input_new(:,:,1)==0 | input_new(:,:,2)==0 | input_new(:,:,3)==0;
    if sum(input_invalid_mask(:))
        disp('Warning! input has zero values!')
        figure(3), imshow(input_invalid_mask)
    end
    
    %% save files
    imwrite(input_new, [OutDir_new, 'MPI-main-clean/', frame_name]);
    imwrite(albedo_new, [OutDir_new, 'MPI-main-albedo/', frame_name]);
    imwrite(shading_new, [OutDir_new, 'MPI-main-shading/', frame_name]);

end

