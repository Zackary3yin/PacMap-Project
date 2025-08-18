%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step4_1_concat_features_and_scores_multiCenter.m
% 多中心模式：拼接 EEG 特征 + 模型概率 + sum/mean，并生成 csv_ind
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 定义项目根目录 & 所有中心名 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 可按需修改

% ———— 2. 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % ———— 3. 定义路径 ————
    featDir  = fullfile(projRoot, 'feature', center);
    scoreDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction');
    outDir   = fullfile(scoreDir, 'model_prediction_fet');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % ———— 4. 获取所有特征文件 ————
    featFiles = dir(fullfile(featDir, '*.mat'));
    if isempty(featFiles)
        fprintf('⚠️  中心 %s 无特征文件，跳过\n\n', center);
        continue;
    end

    % ———— 5. 遍历每个特征文件 ————
    for i = 1:numel(featFiles)
        origName = featFiles(i).name(1:end-4);
        coreName = regexprep(origName, '^feature_', '');

        % 加载特征结构
        Sfeat = load(fullfile(featDir, featFiles(i).name));
        xdat  = Sfeat.x;
        Nframe = numel(xdat.lv_l20);

        % 加载对应 SPaRCNet 概率输出
        scoreFile = fullfile(scoreDir, [coreName '_score.mat']);
        if ~exist(scoreFile, 'file')
            warning('❌ 缺失 score 文件: %s，跳过', scoreFile);
            continue;
        end
        Sscore = load(scoreFile);
        Y      = Sscore.Y_model;
        [~, pCols] = size(Y);

        % 拼接特征 + 概率 + sum/mean
        k = 1;
        for j = 1:Nframe
            feat_vec = [
                xdat.d0MeanMaxAmp(j),  xdat.deltakurtosis(j), xdat.thetakurtosis(j), ...
                xdat.alphakurtosis(j), xdat.betakurtosis(j),  xdat.deltameanrat(j), ...
                xdat.thetameanrat(j),  xdat.alphameanrat(j),  xdat.betameanrat(j), ...
                xdat.deltastdrat(j),   xdat.thetastdrat(j),   xdat.alphastdrat(j), ...
                xdat.betastdrat(j),    xdat.BCI(j),           xdat.SIQ(j), ...
                xdat.SIQ_delta(j),     xdat.SIQ_theta(j),     xdat.SIQ_alpha(j), ...
                xdat.SIQ_beta(j),      xdat.lv_l20(j)
            ];

            if j == 1
                fLen = numel(feat_vec);
                totalCols = fLen + pCols + 2; % sum + mean
                csv_data_fe = zeros(Nframe*5, totalCols);
            end

            for t = 0:4
                prob_vec = Y(k+t, :);
                if pCols > 1
                    sum_p  = sum(prob_vec(2:end));
                    mean_p = mean(prob_vec(2:end));
                else
                    sum_p  = prob_vec(1);
                    mean_p = prob_vec(1);
                end
                csv_data_fe(k+t, :) = [feat_vec, prob_vec, sum_p, mean_p];
            end
            k = k + 5;
        end

        % 计算每帧最大概率索引
        idx_offset = fLen;
        csv_ind = zeros(size(csv_data_fe, 1), 1);
        for ii = 1:size(csv_data_fe, 1)
            probs = csv_data_fe(ii, idx_offset+1 : idx_offset + pCols);
            [~, csv_ind(ii)] = max(probs);
        end

        % 保存结果
        save(fullfile(outDir, [coreName '.mat']), 'csv_data_fe', 'csv_ind', '-v7.3');
        fprintf('✅ (%3d/%3d) %s 处理完成\n', i, numel(featFiles), coreName);
    end

    fprintf('✅ 中心 %s 完成全部处理\n\n', center);
end