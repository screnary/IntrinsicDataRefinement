% % % Reconstruct shading and albedo by shifting (mean, std) statistics.
clear all;
close all;

DataSet = 'MPI';

DataDir = ['../datasets/',DataSet,'/'];
DumpDir = ['../datasets/', DataSet, '/temp_refine_2/'];
OutDir = ['../datasets/', DataSet, '/refined_test/'];

MaskDir = [DataDir, 'MPI-main-mask/'];
InputDir = [DataDir, 'MPI-main-clean/'];
AlbedoDir = [DataDir, 'MPI-main-albedo/'];
ShadingDir = [DataDir, 'MPI-main-shading/'];
file_lists = dir([ShadingDir, '*.png']);

for n = 591:640 %591:640, 741:790 %length(file_lists)
    gap = 6.0;
    threshold = 0.985;
    scale_factor1 = 1.5;
    scale_factor2 = 1.5;
    lle_flag = true;
    if n > 200 && n <= 300  % bandage
        threshold = 0.98;
        scale_factor2 = 6.7;
    elseif n > 300 && n <= 400  % cave, girl slash dragon
        threshold = 0.98;
        gap = 7.0;
        scale_factor1 = 3.5;
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
        threshold = 0.97;
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
    
    L_i(L_i < 4) = 4;
    input_lab_filtered = input_lab;
    input_lab_filtered(:,:,1) = L_i;
    input_filtered = lab2rgb(input_lab_filtered);  % remove zero pixels !
    
    L_s(L_s < 4) = 4;
    shading_lab_filtered = shading_lab;
    shading_lab_filtered(:,:,1) = L_s;
    shading_filtered = lab2rgb(shading_lab_filtered);  % remove zero pixels !
    figure(1), imshow(shading_filtered)
    % get validate pixels in L_albedo_rec
    a_valid_mask = L_a_rec < 100;  % use this as valid
    s_valid_mask = L_s_rec < 95;   % [95] or use this. more strict
    
    % get the statistics of albedo
    L_arec_valid = L_a_rec(s_valid_mask & a_valid_mask);
    mu_arec = mean(L_arec_valid);
    std_arec = std(L_arec_valid);
    
    mu_a = mean(L_a(:));
    std_a = std(L_a(:));
    
    % distribution shift
    L_a_shift = (L_a - mu_a) * 0.99*std_arec / std_a + 1.01*mu_arec;
    if min(L_a_shift(:)) <= 0
        L_a_shift_normed = 100 * (L_a_shift - min(L_a_shift(:))+1) / (max(L_a_shift(:))+1 - min(L_a_shift(:))/scale_factor1);
    else
        L_a_shift_normed = 100 * (L_a_shift - min(L_a_shift(:))/scale_factor2+1) / (max(L_a_shift(:))+1 - 0);
    end
    
    if n > 300 && n <= 400  % cave, girl slash dragon
        L_a_shift_normed(L_a<4) = 35;
    end

    L_s_ = 100 * L_i ./ L_a_shift_normed;

    %% check invalid values in L_shading_rec
    if lle_flag
%     if sum(sum(L_s_ > 100))  % if there are invalid values in L_s_
        [N, edges] = histcounts(L_s_);
        N_cum = cumsum(N);
        percent = N_cum ./ (height*width);
        for j = 1:length(N)
            if percent(j) > threshold % 0.999, 0.98
                up_bound = 0.5 * (edges(j)+edges(j+1));
                break;
            end
        end
        invalid_mask = L_s_ >= up_bound | L_s_ <= 0;
%         imshow(invalid_mask);
        up_in_mask = L_s_ >= up_bound;
        down_in_mask = L_s_ <= 0;
        % % fill hole using LLE
        tic
        L_s_refine = LLE_smoothing(L_s_, input_filtered, invalid_mask, 15);
%         L_s_refine = LLE_smoothing(L_s_, shading_filtered, invalid_mask, 15); %591:640; 741:790
%         L_s_refine = LLE_smoothing(L_s_, albedo, invalid_mask, 15);  % not good
        toc

%         L_s_refine = L_s_;                     % simplified,for test
%         L_s_refine(L_s_>up_bound) = up_bound;  % simplified

        L_s_new = 100 * (L_s_refine - 0) / (up_bound-0);
%     end
    else  % direct combine
        L_s_new = L_s;
        L_s_new(L_s > 100) = 100;
        L_s_new(L_s < 1) = 1;
    end

    %% get the rgb images
    shading_new_lab = shading_lab;
    shading_new_lab(:,:,1) = L_s_new;
    albedo_new_lab = albedo_lab;
    albedo_new_lab(:,:,1) = L_a_shift_normed;
    
    albedo_new = lab2rgb(albedo_new_lab);
    shading_new = lab2rgb(shading_new_lab);
    input_new = albedo_new .* shading_new;
    
    if sum(L_s_new(:) == 0) > 0
        disp('Warning! shading has zero values!')
        figure(1), imshow([input_new; albedo_new; shading_new])
        figure(2), imshow([input_new ./ shading_new; input_new ./ albedo_new])
    end
%     figure(1), imshow(input)
%     figure(2), imshow(L_a_rec, [])
%     figure(3), imshow(L_a_shift_normed, [])
    
%     figure(4), imshow([shading; shading_new])
%     figure(5), imshow([albedo; albedo_new])
%     figure(6), imshow([input; input_new])
    
    %% save files
    imwrite(input_new, [OutDir, 'MPI-main-clean/', frame_name]);
    imwrite(albedo_new, [OutDir, 'MPI-main-albedo/', frame_name]);
    imwrite(shading_new, [OutDir, 'MPI-main-shading/', frame_name]);

end

