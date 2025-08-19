%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step4_1_concat_features_and_scores_multiCenter.m
% 多中心模式：拼接 EEG 特征 + 模型概率 + sum/mean，并生成 csv_ind
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
dataRoot = 'F:\ICARE_organized';                   %%% 修改：外接硬盘数据根（只读）
projRoot = fileparts(mfilename('fullpath'));       %%% 修改：当前脚本目录（输出与score所在处）

% ———— 1) 中心列表（按需修改）———
centers  = {'BIDMC','MGH','ULB'};                  %%% 修改：示例中心（与目前ICARE_organized一致）

% ———— 2) 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % ———— 3) 定义路径 ————
    featDir  = fullfile(dataRoot, 'feature', center);                             %%% 修改：从外接硬盘读特征
    scoreDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction');     %%% 修改：从脚本目录读 step4 生成的 score
    outDir   = fullfile(projRoot, 'GUI_results', center, 'model_prediction_fet'); %%% 修改：输出到脚本目录
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % ———— 4) 获取所有特征文件 ————
    featFiles = dir(fullfile(featDir, '*.mat'));
    if isempty(featFiles)
        fprintf('⚠️  中心 %s 无特征文件，跳过\n\n', center);
        continue;
    end

    % ———— 5) 遍历每个特征文件 ————
    for i = 1:numel(featFiles)
        origName = featFiles(i).name(1:end-4);                 % e.g. feature_ICARE_xxx_YYYYMMDD_HHMMSS
        coreName = regexprep(origName, '^feature_', '');       % 去掉前缀，得到 ICARE_xxx_...

        % —— 5.1 加载特征结构 ——
        Sfeat = load(fullfile(featDir, featFiles(i).name));
        if ~isfield(Sfeat, 'x')
            warning('❌ 特征文件缺少变量 x: %s，跳过', featFiles(i).name);
            continue;
        end
        xdat  = Sfeat.x;
        % 关键字段健壮性检查（可按需增减）
        need_fields = {'lv_l20','d0MeanMaxAmp','deltakurtosis','thetakurtosis','alphakurtosis','betakurtosis', ...
                       'deltameanrat','thetameanrat','alphameanrat','betameanrat', ...
                       'deltastdrat','thetastdrat','alphastdrat','betastdrat', ...
                       'BCI','SIQ','SIQ_delta','SIQ_theta','SIQ_alpha','SIQ_beta'};
        miss = need_fields(~isfield(xdat, need_fields));
        if ~isempty(miss)
            warning('❌ 特征缺字段(%d): %s，文件=%s，跳过', numel(miss), strjoin(miss,','), featFiles(i).name);
            continue;
        end
        Nframe = numel(xdat.lv_l20);

        % —— 5.2 加载对应 SPaRCNet 概率输出（来自 step4 的保存） ——
        scoreFile = fullfile(scoreDir, [coreName '_score.mat']);  %%% 修改：读取脚本目录的score
        if ~exist(scoreFile, 'file')
            warning('❌ 缺失 score 文件: %s，跳过', scoreFile);
            continue;
        end
        Sscore = load(scoreFile);
        if     isfield(Sscore, 'Y_model')                       %%% 修改：优先 Y_model
            Y = Sscore.Y_model;
        elseif isfield(Sscore, 'score')
            Y = Sscore.score;
        elseif isfield(Sscore, 'Y')
            Y = Sscore.Y;
        elseif isfield(Sscore, 'Ycsv')
            Y = Sscore.Ycsv;
        else
            warning('❌ %s 中未找到 Y_model/score/Y/Ycsv，跳过', scoreFile);
            continue;
        end
        if istable(Y); Y = table2array(Y); end
        if ~isnumeric(Y) || isempty(Y)
            warning('❌ %s 中的概率矩阵无效，跳过', scoreFile);
            continue;
        end

        [nRow, pCols] = size(Y);

        % —— 5.3 尺寸健壮性：期望 Y 对应 Nframe*5 行（与你原逻辑一致） ——
        % 若行数不足/超出，按可用范围截取（保证不越界）
        expected = Nframe * 5;
        if nRow < expected
            warning('⚠️ 概率行数(%d) < 期望(%d)，按实际可用行处理（中心：%s，%s）', nRow, expected, center, coreName);
            maxFrames = floor(nRow / 5);          % 仅能覆盖的帧数
        else
            maxFrames = Nframe;
        end

        % —— 5.4 拼接特征 + 概率 + sum/mean ——
        k = 1;
        for j = 1:maxFrames
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
                % 预分配：按可用帧数 * 5 行
                csv_data_fe = zeros(maxFrames * 5, totalCols);
            end

            for t = 0:4
                rowIdx = k + t;
                if rowIdx > nRow
                    break;  % 保护
                end
                prob_vec = Y(rowIdx, :);

                if pCols > 1
                    sum_p  = sum(prob_vec(2:end));
                    mean_p = mean(prob_vec(2:end));
                else
                    sum_p  = prob_vec(1);
                    mean_p = prob_vec(1);
                end
                csv_data_fe(rowIdx, :) = [feat_vec, prob_vec, sum_p, mean_p];
            end
            k = k + 5;
        end

        % 若 Y 行数少于预期，可能尾部仍为 0；这里可按需裁掉"全零行"
        % （保持与你原逻辑一致，这里先不裁，保留占位）

        % —— 5.5 计算每帧最大概率索引（按列偏移） ——
        idx_offset = fLen;
        rows_valid = find(any(csv_data_fe, 2), 1, 'last');    % 找到最后一行非零（防止尾部 0 行）
        if isempty(rows_valid); rows_valid = size(csv_data_fe,1); end
        csv_ind = zeros(rows_valid, 1);
        for ii = 1:rows_valid
            probs = csv_data_fe(ii, idx_offset+1 : idx_offset + pCols);
            [~, csv_ind(ii)] = max(probs);
        end

        % —— 5.6 保存结果 ——
        save(fullfile(outDir, [coreName '.mat']), 'csv_data_fe', 'csv_ind', '-v7.3');
        fprintf('✅ (%3d/%3d) %s 处理完成 | 行=%d, 概率列=%d\n', i, numel(featFiles), coreName, rows_valid, pCols);
    end

    fprintf('✅ 中心 %s 完成全部处理\n\n', center);
end