import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const PollsModule = buildModule("PollsModule", (m) => {
  const polls = m.contract("Polls");

  return { polls };
});

export default PollsModule;
