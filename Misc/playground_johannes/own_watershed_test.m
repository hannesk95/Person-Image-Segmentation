%% Clean Up
close all;
clear;
clc

%% Step 1: Read in the Color Image and Convert it to Grayscale
rgb = imread('00000837.jpg');
I = rgb2gray(rgb);
imshow(I)

%% Step 2: Use the Gradient Magnitude as the Segmentation Function
gmag = imgradient(I);
imshow(gmag,[])
title('Gradient Magnitude')

% Can you segment the image by using the watershed transform directly on the gradient magnitude?
L = watershed(gmag);
Lrgb = label2rgb(L);
imshow(Lrgb)
title('Watershed Transform of Gradient Magnitude')

% No. Without additional preprocessing such as the marker computations below, using the watershed transform directly often results in "oversegmentation."

%% Step 3: Mark the Foreground Objects

se = strel('disk',20);
Io = imopen(I,se);
imshow(Io)
title('Opening')

Ie = imerode(I,se);
Iobr = imreconstruct(Ie,I);
imshow(Iobr)
title('Opening-by-Reconstruction')

Ioc = imclose(Io,se);
imshow(Ioc)
title('Opening-Closing')

Iobrd = imdilate(Iobr,se);
Iobrcbr = imreconstruct(imcomplement(Iobrd),imcomplement(Iobr));
Iobrcbr = imcomplement(Iobrcbr);
imshow(Iobrcbr)
title('Opening-Closing by Reconstruction')

fgm = imregionalmax(Iobrcbr);
imshow(fgm)
title('Regional Maxima of Opening-Closing by Reconstruction')

I2 = labeloverlay(I,fgm);
imshow(I2)
title('Regional Maxima Superimposed on Original Image')

se2 = strel(ones(5,5));
fgm2 = imclose(fgm,se2);
fgm3 = imerode(fgm2,se2);

fgm4 = bwareaopen(fgm3,20);
I3 = labeloverlay(I,fgm4);
imshow(I3)
title('Modified Regional Maxima Superimposed on Original Image')

%% Step 4: Compute Background Markers

bw = imbinarize(Iobrcbr);
imshow(bw)
title('Thresholded Opening-Closing by Reconstruction')

D = bwdist(bw);
DL = watershed(D);
bgm = DL == 0;
imshow(bgm)
title('Watershed Ridge Lines)')

%% Step 5: Compute the Watershed Transform of the Segmentation Function.

gmag2 = imimposemin(gmag, bgm | fgm4);
L = watershed(gmag2);

%% Step 6: Visualize the Result

labels = imdilate(L==0,ones(3,3)) + 2*bgm + 3*fgm4;
I4 = labeloverlay(I,labels);
imshow(I4)
title('Markers and Object Boundaries Superimposed on Original Image')

Lrgb = label2rgb(L,'jet','w','shuffle');
imshow(Lrgb)
title('Colored Watershed Label Matrix')