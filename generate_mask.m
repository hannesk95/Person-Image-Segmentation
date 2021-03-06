function foreground_mask = generate_mask(tensor_l, rois, do_plot)
    if nargin < 3
        do_plot = false;
    end

    % Get number of Regions of Interest
    N_rois = size(rois, 1);
    
    % Extract first image from tensor
    I1 = tensor_l(:,:, 1);
    padding_h = 0;
    padding_v = 20;
    
    % Initialize foreground mask with zeros
    foreground_mask = zeros(size(I1));
    
    for i = 1:N_rois
        %% Extract ROI informations
        boundary_box = rois{i, 1};
        contour_point = rois{i , 2};
            
            
        %% Extract image area of ROI
        top_left = round(boundary_box(1,:)) - [padding_h padding_v];
        top_left = max(top_left, [1 1]);
        bottom_right = round(boundary_box(2,:)) + [padding_h padding_v];
        bottom_right = min(bottom_right, size(I1'));
            
        I1_detail = I1(top_left(2):bottom_right(2),top_left(1):bottom_right(1));
            
        if do_plot
            figure
            subplot(1,2,1);
            imshow(I1_detail);
            title('Region of Interest')
        end
            
        %% Generate boundary mask inside of ROI
        mask = zeros(size(I1_detail));
        if ~isempty(contour_point)
            %top_left = boundary_box(1,:) - [padding_h padding_v];
            %top_left = max(top_left, [1 1]);
            %contour_point_0 = contour_point - top_left';
            %mask = roipoly(mask,contour_point_0(1,:)',contour_point_0(2,:)');
            mask = generate_ellipse(size(mask,2),size(mask,1));
        else
            % No contour points provided, use generic ellipse
            mask = generate_ellipse(size(mask,2),size(mask,1));
        end
            
        if do_plot
            subplot(1,2,2);
            imshow(uint8(mask) * 255 * 0.3 + I1_detail * 0.7);
            title('Over-approximated mask')
        end
            
        %% Perform watershed segmentation
        labels = watershed_segmentation(I1_detail, do_plot);    
         
        %% Calculate relative area of each segment inside the over-approximated mask
        N_segments = max(labels(:));
        segment_area = zeros(1, N_segments);
        for k = 1:N_segments
            region_pixels = labels(:) == k;
            in_mask = nnz(mask(region_pixels));
            segment_area(k) = in_mask / nnz(region_pixels);
        end        
            
        if do_plot
            Lrgb = label2rgb(labels,'jet','w','shuffle');
            figure
            imshow(Lrgb - uint8(~mask) * 150);
            title('Watershed segmentation')
        end
            
        %% Weight segments with their area inside the mask
        mask_weighted = zeros(size(mask));
        for k = 1:N_segments
            segment_idx = labels(:) == k;
            mask_weighted(segment_idx) = exp(1 - 1 / (segment_area(k) ));
        end 
        % Give central pixels a stronger weight
        mask_weighted = mask_weighted .* generate_weighting(size(mask,2), size(mask,1));
         
        %% Add weighted mask to foreground mask
        top_left = round(boundary_box(1,:)) - [padding_h padding_v];
        top_left = max(top_left, [1 1]);
        bottom_right = top_left + size(mask') - [1 1];
        bottom_right = min(bottom_right, size(foreground_mask'));
        foreground_rows = top_left(2):bottom_right(2);
        foreground_cols = top_left(1):bottom_right(1);
        foreground_mask(foreground_rows, foreground_cols) = foreground_mask(foreground_rows, foreground_cols) + mask_weighted;
        
    end
        
    if do_plot
        figure
        h = surf(foreground_mask);
        set(h,'LineStyle','none')
        title('Segment weights')
    end
    
    %% Binarize foreground mask
    foreground_mask = foreground_mask >= 0.85;
    
    % Remove segment partition lines
    se = strel('disk',1);
    foreground_mask = imdilate(foreground_mask,se);
    
end

