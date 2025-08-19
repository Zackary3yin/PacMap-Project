%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_1_aggregate_by_subject_multiCenter.m
% 多中心模式：将 model_prediction_fet 中的样本按被试 ID 聚合
% 输出为 model_prediction_fet_s/，并重算 csv_ind_s
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
projRoot = fileparts(mfilename('fullpath'));                 %%% 修改：输出/输入均以"当前脚本目录"为根
% （本脚本只处理 GUI_results 下的数据，不直接访问外接硬盘的原始 eeg/feature）

% ———— 1) 定义中心列表 ————
centers  = {'BIDMC','MGH','ULB'};                            %%% 修改：示例中心，按你的数据增减

% ———— 2) 遍历中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % GUI_results 路径：读取 step4_1 结果，写聚合结果
    dataDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet');     %%% 修改
    outDir  = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet_s');   %%% 修改

    if ~exist(dataDir, 'dir')
        warning('⚠️ 找不到目录: %s，跳过该中心', dataDir);
        continue;
    end
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % ———— 3) 获取所有 .mat 文件 ————
    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        warning('⚠️ 中心 %s 没有 .mat 特征文件，跳过', center);
        continue;
    end
    fileNames = {files.name}';

    % ———— 4) 提取唯一被试 ID（文件名前两段） ————
    tmpID = split(fileNames, '_');
    subjectIDs = strcat(tmpID(:,1), '_', tmpID(:,2));  % e.g. ICARE_0012
    uniqueIDs = unique(subjectIDs);

    % ———— 5) 读取一份样本的列结构（用于推导列区间）———
    tmp = load(fullfile(dataDir, fileNames{1}), 'csv_data_fe');
    if ~isfield(tmp,'csv_data_fe')
        error('❌ 文件缺少 csv_data_fe: %s', fileNames{1});
    end
    csv0  = tmp.csv_data_fe;
    nCols = size(csv0, 2);

    % ====== 列定义 ======
    % 你在 step4_1 中用到的"特征个数 fLen"和"概率列数 pCols"：
    %   csv_data_fe = [feat(1:fLen), probs(1:pCols), sum, mean]
    % 原脚本写死 fLen=19；如果你的特征实际是 20 个，请把下一行改成 20。
    fLen  = 19;                                              %%% 修改：保留你原来的设置；若你特征=20，请改为 20
    pCols = nCols - fLen - 2;
    if pCols <= 0
        error('❌ 列数推断失败：nCols=%d, fLen=%d → pCols=%d', nCols, fLen, pCols);
    end
    pStart = fLen + 1;
    pEnd   = fLen + pCols;

    % ———— 6) 按被试聚合 ————
    for i = 1:numel(uniqueIDs)
        sid = uniqueIDs{i};  % 被试 ID
        idx = find(strcmp(subjectIDs, sid));
        agg = [];
        for j = 1:numel(idx)
            S = load(fullfile(dataDir, fileNames{idx(j)}), 'csv_data_fe');
            if ~isfield(S,'csv_data_fe')
                warning('❌ 缺少 csv_data_fe：%s（已跳过）', fileNames{idx(j)});
                continue;
            end
            % 健壮性：保证列数一致
            if size(S.csv_data_fe,2) ~= nCols
                warning('⚠️ 列数不一致：%s（%d 列）≠ 基准（%d 列），尝试按前 %d 列对齐',
                        fileNames{idx(j)}, size(S.csv_data_fe,2), nCols, min(size(S.csv_data_fe,2), nCols));
                S.csv_data_fe = S.csv_data_fe(:, 1:min(size(S.csv_data_fe,2), nCols));
                if size(S.csv_data_fe,2) < nCols
                    S.csv_data_fe(:, end+1:nCols) = 0; % 不足则补零
                end
            end
            agg = [agg; S.csv_data_fe];  % 纵向拼接
        end

        if isempty(agg)
            warning('⚠️ 被试 %s 聚合为空，跳过保存', sid);
            continue;
        end

        % —— 重算分类索引 csv_ind_s（逐行在概率区间 [pStart:pEnd] 取 argmax）——
        N = size(agg, 1);
        csv_ind_s = zeros(N, 1);
        for k = 1:N
            probs = agg(k, pStart:pEnd);
            [~, csv_ind_s(k)] = max(probs);
        end

        % —— 保存该被试结果 ——（输出在脚本目录）
        save(fullfile(outDir, [sid '.mat']), 'agg', 'csv_ind_s', '-v7.3');
        fprintf('✅ (%d/%d) 已保存被试聚合: %s（行=%d）\n', i, numel(uniqueIDs), sid, N);
    end

    fprintf('✅ 中心 %s 聚合完成，共 %d 名被试\n', center, numel(uniqueIDs));
end