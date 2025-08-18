%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_1_aggregate_by_subject_multiCenter.m
% 多中心模式：将 model_prediction_fet 中的样本按被试 ID 聚合
% 输出为 model_prediction_fet_s/，并重算 csv_ind_s
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 定义根目录 & 中心列表 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 可根据实际情况添加

% ———— 2. 遍历中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    dataDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet');
    outDir  = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet_s');

    if ~exist(dataDir, 'dir')
        warning('⚠️ 找不到目录: %s，跳过该中心', dataDir);
        continue;
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % ———— 3. 获取所有 .mat 文件 ————
    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        warning('⚠️ 中心 %s 没有 .mat 特征文件，跳过', center);
        continue;
    end
    fileNames = {files.name}';

    % ———— 4. 提取唯一被试 ID（文件名前两段） ————
    tmpID = split(fileNames, '_');
    subjectIDs = strcat(tmpID(:,1), '_', tmpID(:,2));  % e.g. ICARE_0012
    uniqueIDs = unique(subjectIDs);

    % ———— 5. 特征维度定义 ————
    tmp = load(fullfile(dataDir, fileNames{1}), 'csv_data_fe');
    csv0 = tmp.csv_data_fe;
    fLen = 19;
    nCols = size(csv0, 2);
    pCols = nCols - fLen - 2;
    pStart = fLen + 1;
    pEnd = fLen + pCols;

    % ———— 6. 聚合每个被试的所有数据 ————
    for i = 1:numel(uniqueIDs)
        sid = uniqueIDs{i};  % 被试 ID
        idx = find(strcmp(subjectIDs, sid));
        agg = [];
        for j = 1:numel(idx)
            S = load(fullfile(dataDir, fileNames{idx(j)}), 'csv_data_fe');
            agg = [agg; S.csv_data_fe];  % 拼接数据
        end

        % 重算分类索引 csv_ind_s
        N = size(agg, 1);
        csv_ind_s = zeros(N, 1);
        for k = 1:N
            [~, csv_ind_s(k)] = max(agg(k, pStart:pEnd));
        end

        % 保存该被试结果
        save(fullfile(outDir, [sid '.mat']), 'agg', 'csv_ind_s', '-v7.3');
        fprintf('✅ (%d/%d) 已保存被试聚合: %s\n', i, numel(uniqueIDs), sid);
    end

    fprintf('✅ 中心 %s 聚合完成，共 %d 名被试\n', center, numel(uniqueIDs));
end