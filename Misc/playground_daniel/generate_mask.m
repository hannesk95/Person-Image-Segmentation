function foreground_mask = generate_mask(tensor_l, tensor_r, rois, do_plot)
    if nargin < 4
        do_plot = false;
    end

    N_rois = size(rois, 1);
    N_frames = size(tensor_l, 3) - 1;
        
    I1 = tensor_l(:,:, 1);
    padding_h = 0;
    padding_v = 0;
    
    foreground_mask = zeros(size(I1));
    
    for i = 1:N_rois
        %% Extract ROI informations
        is_empty = rois{i, 1};
        boundary_boxes = rois{i, 2};
        countour_points = rois{i , 3};
        for j = 1:N_frames
            
            if is_empty(j) == true
                continue;
            end
            
            I2 = tensor_l(:,:, j + 1);
            
            %% Get Image of ROI
            boundary_box = boundary_boxes(:,:,j);
            top_left = round(boundary_box(1,:)) - [padding_h padding_v];
            top_left = max(top_left, [1 1]);
            bottom_right = round(boundary_box(2,:)) + [padding_h padding_v];
            bottom_right = min(bottom_right, size(I1'));
            
            I1_detail = I1(top_left(2):bottom_right(2),top_left(1):bottom_right(1));
            I2_detail = I2(top_left(2):bottom_right(2),top_left(1):bottom_right(1));
            
            if do_plot
                figure
                subplot(2,2,1);
                imshow(I1_detail);
            end
            
            %% Generate boundary mask
            boundary_box = boundary_boxes(:,:,j);
            top_left = boundary_box(1,:) - [padding_h padding_v];
            top_left = max(top_left, [1 1]);
            contour_point = cell2mat(countour_points{j});
            contour_point = contour_point - top_left';
            mask = zeros(size(I1_detail));
            mask = roipoly(mask,contour_point(1,:)',contour_point(2,:)');
            se = strel('disk', 5);
            mask = imdilate(mask,se); 
            
            if do_plot
                subplot(2,2,2);
                imshow(uint8(mask) * 255 * 0.3 + I1_detail * 0.7);
            end
            
            %% Perform watershed segmentation
            labels = watershed_segmentation(I1_detail);    
            
            %% Check which segments are (mostly) inside of the mask
            N_segments = max(labels(:));
            segment_area = zeros(1, N_segments);
            for k = 1:N_segments
                region_pixels = labels(:) == k;
                in_mask = nnz(mask(region_pixels));
                segment_area(k) = in_mask / nnz(region_pixels);
            end        
            
            if do_plot
                Lrgb = label2rgb(labels,'jet','w','shuffle');
                subplot(2,2,3);
                imshow(Lrgb - uint8(~mask) * 150);
            end
            
            %% Weight segments with their area inside the mask
            mask_weighted = zeros(size(mask));
            for k = 1:N_segments
                segment_idx = labels(:) == k;
                mask_weighted(segment_idx) = exp(1 - 1 / (segment_area(k) ));
            end 
            mask_weighted = mask_weighted .* generate_prototype(size(mask,2), size(mask,1));
            
            %% Add weighted mask to foreground mask
            boundary_box = boundary_boxes(:,:,j);
            top_left = round(boundary_box(1,:)) - [padding_h padding_v];
            top_left = max(top_left, [1 1]);
            bottom_right = top_left + size(mask') - [1 1];
            bottom_right = min(bottom_right, size(foreground_mask'));
            foreground_rows = top_left(2):bottom_right(2);
            foreground_cols = top_left(1):bottom_right(1);
            foreground_mask(foreground_rows, foreground_cols) = foreground_mask(foreground_rows, foreground_cols) + mask_weighted;
        end
    end
        
    if do_plot
        figure
        h = surf(foreground_mask);
        set(h,'LineStyle','none')
    end
    
    %% Binarize foreground mask
    se = strel('disk', 1);
    foreground_mask = foreground_mask >= 0.6 * (log(N_frames) + 1);
    foreground_mask = imdilate(foreground_mask, se);
    
    %% Smothen edges
    foreground_mask = imgaussfilt(double(foreground_mask),3) > 0.5;
    
    %% Fill holes    
    se = strel('disk', 5);
    foreground_mask = imdilate(foreground_mask, se);
end

