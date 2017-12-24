#!/usr/bin/env Rscript

suppressMessages(library(plyr))
suppressMessages(library(dplyr))
suppressMessages(library(ggplot2))
suppressMessages(library(optparse))

option.list <- list(
    make_option(c("-r", "--runtime"), default = "runtime.pdf", metavar = "FILE",
                help = "Output PDF file with runtime analysis. [default: %default]"),
    make_option(c("-m", "--messages"), default = "messages.pdf", metavar = "FILE",
                help = "Output PDF file with communication analysis. [default: %default]"))

opt.parser <- OptionParser(option_list = option.list,
                           usage = "%prog [options]")
opt <- parse_args(opt.parser, positional_arguments = 1)

log.dir <- opt$args

if (!dir.exists(log.dir)) {
    stop(paste("Directory", log.dir, "does not exist"))
}

plan <- read.csv(file.path(log.dir, 'experiment_plan.csv'))
runs <- read.csv(file.path(log.dir, 'experiment_logs.csv'))

pdf(opt$options$runtime, width = 7, height = 4)

res <- plan %>%
    inner_join(runs) %>%
    group_by(COLL, k, PAR, L, o, g, P, F) %>%
    filter(UnreachedNodes == 0) %>%
    summarise(avg_runtime = mean(TotalRuntime),
              avg_msg = mean(MsgTask),
              sd_runtime = sd(TotalRuntime),
              sd_msg = sd(MsgTask)) %>%
    ungroup() %>%
    filter((COLL != 'checked_corrected_gossip_bcast' | k > 0) &
           (COLL != 'checked_gossip_corrected_optimal_bcast' | k <= -3)) %>%
    collect()

max.runtime = max(res$avg_runtime + res$sd_runtime + 0.1)

node.list <- (2^c(1:17)) - 1

res <- mutate(res, COLL = revalue(COLL,
                                  c("checked_corrected_binomial_bcast" = "Checked binomial",
                                    "checked_corrected_optimal_bcast" = "Checked optimal",
                                    "phased_checked_corrected_binomial_bcast" = "Phased binomial",
                                    "checked_corrected_gossip_bcast" = "Checked gossip",
                                    "checked_gossip_corrected_optimal_bcast" = "Checked gossip tree")))

res <- mutate(res, k = as.factor(k))

p <- res %>%
    group_by(PAR, L, o, g, F) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_runtime,
                          lty = COLL, col = k)) +
            ylim(0, max.runtime) +
            ggtitle("Scalability at the same fault rate",
                    subtitle = paste("F =", .$F, "%", "L =", .$L, "o = ", .$o, "g =", .$g, "PAR =", .$PAR)) +
            ylab("Runtime, steps") +
            guides(lty = guide_legend(title = "Collective")) +
            theme_linedraw(base_size = 10) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

add.log.scale <- function(p) p + scale_x_log10(breaks = node.list, labels = node.list)

print(p$plots)
print(lapply(p$plots, function(p) p +
                                  scale_x_continuous() +
                                  geom_errorbar(aes(x = P,
                                                    ymin = avg_runtime - sd_runtime,
                                                    ymax = avg_runtime + sd_runtime,
                                                    lty = COLL, group = k), alpha=0.5)))
print(lapply(p$plots, add.log.scale))

p <- res %>%
    filter(F %in% c(1, 2, 4, 6, 8, 10)) %>%
    collect() %>%
    group_by(L, o, g, k, PAR, COLL) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_runtime, color = as.factor(F))) +
            ylim(0, max.runtime) +
            ggtitle("Sturdiness with growing number of faults",
                    subtitle = paste(.$COLL, "L =", .$L, "o = ", .$o, "g =", .$g, "k =", .$k, "PAR =", .$PAR)) +
            ylab("Runtime, steps") +
            guides(color = guide_legend(title = "F (%)")) +
            scale_color_brewer(type = "seq", palette="Oranges") +
            theme_linedraw() +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

print(p$plots)
print(lapply(p$plots, add.log.scale))

dev.off()

pdf(opt$options$messages, width = 7, height = 4)

max.msg = max(res$avg_msg + res$sd_msg + 0.1)

p <- res %>%
    group_by(PAR, L, o, g, F) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_msg, linetype = COLL, col = k)) +
            ylim(0, max.msg) +
            ggtitle("Scalability at the same fault rate",
                    subtitle = paste("F =", .$F, "%", "L =", .$L, "o = ", .$o, "g =", .$g, "PAR =", .$PAR)) +
            ylab("Messages, count") +
            guides(lty = guide_legend(title = "Collective")) +
            theme_linedraw(base_size = 10) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

print(p$plots)
print(lapply(p$plots, function(p) p +
                                  scale_x_continuous() +
                                  geom_errorbar(aes(x = P,
                                                    ymin = avg_msg - sd_msg,
                                                    ymax = avg_msg + sd_msg,
                                                    lty = COLL,
                                                    col = k), alpha=0.5)))
print(lapply(p$plots, add.log.scale))

p <- res %>%
    filter(F %in% c(1, 2, 4, 6, 8, 10)) %>%
    collect() %>%
    group_by(L, o, g, k, PAR, COLL) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_msg, color = as.factor(F))) +
            ylim(0, max.msg) +
            ggtitle("Sturdiness with growing number of faults",
                    subtitle = paste(.$COLL, "L =", .$L, "o = ", .$o, "g =", .$g, "k =", .$k, "PAR =", .$PAR)) +
            ylab("Messages, count") +
            guides(color = guide_legend(title = "F (%)")) +
            scale_color_brewer(type = "seq", palette="Oranges") +
            theme_linedraw() +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )
print(p$plots)
print(lapply(p$plots, add.log.scale))

dev.off()
