/**
 * Machine synchronization.
 *
 * Handles REST fetching, WebSocket update processing, and metadata decryption
 * for registered machines (CLI daemons).
 */
import { Machine } from 'common';
import { Logger } from 'common';
import { MachineApi } from 'network';
import { DataKeyManager } from 'encryption';
import { MachineEncryption } from 'encryption';
import { NewMachineBody, UpdateMachineBody } from 'common';

const TAG = 'MachineSync';

/** Decrypted machine metadata structure. */
class DecryptedMachineMeta {
  name: string = '';

  constructor(name: string = '') {
    this.name = name;
  }
}

class MachineSync {
  private machines: Machine[] = [];
  private machineApi: MachineApi = MachineApi.getInstance();
  private dataKeyManager: DataKeyManager = DataKeyManager.getInstance();
  private machineEncryption: MachineEncryption = MachineEncryption.getInstance();

  /**
   * REST fetch all machines for the authenticated user.
   * Decrypts each machine's DEK and metadata.
   *
   * @returns Decrypted machine list
   */
  async fetchAll(): Promise<Machine[]> {
    try {
      const rawMachines: Machine[] = await this.machineApi.getMachines();
      if (rawMachines.length === 0) {
        Logger.info(TAG, 'No machines found');
        this.machines = [];
        return [];
      }

      for (let i: number = 0; i < rawMachines.length; i++) {
        await this.processMachine(rawMachines[i]);
      }

      this.machines = rawMachines;
      Logger.info(TAG, `Fetched and decrypted ${rawMachines.length} machines`);
      return this.machines;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to fetch machines: ${errMsg}`);
      return [];
    }
  }

  /**
   * Handle a new-machine WebSocket update.
   * Decrypts the DEK and metadata, then inserts the machine.
   */
  async handleNewMachine(body: NewMachineBody): Promise<void> {
    try {
      const machine: Machine = new Machine();
      machine.id = body.id;
      machine.name = body.name;
      machine.metadata = body.metadata;
      machine.metadataVersion = body.metadataVersion;
      machine.daemonState = body.daemonState;
      machine.daemonStateVersion = body.daemonStateVersion;
      machine.active = body.active;
      machine.activeAt = body.activeAt;
      machine.createdAt = body.createdAt;
      machine.updatedAt = body.updatedAt;

      await this.processMachine(machine);

      // Remove existing machine with same id if present
      this.removeMachineById(machine.id);
      this.machines.push(machine);

      Logger.info(TAG, `New machine added: ${machine.id}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle new machine: ${errMsg}`);
    }
  }

  /**
   * Handle an update-machine WebSocket update.
   * Updates metadata, daemonState, and re-decrypts if version changed.
   */
  async handleUpdateMachine(body: UpdateMachineBody): Promise<void> {
    try {
      const machine: Machine | null = this.findMachine(body.machineId);
      if (machine === null) {
        Logger.warn(TAG, `Update machine: machine not found ${body.machineId}`);
        return;
      }

      machine.metadata = body.metadata;
      machine.metadataVersion = body.metadataVersion;
      machine.daemonState = body.daemonState;
      machine.daemonStateVersion = body.daemonStateVersion;
      machine.active = body.active;
      machine.activeAt = body.activeAt;

      await this.decryptMachineMetadata(machine);
      Logger.info(TAG, `Machine updated: ${machine.id}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle update machine: ${errMsg}`);
    }
  }

  /**
   * Get all machines.
   */
  getMachines(): Machine[] {
    return this.machines;
  }

  /**
   * Get only machines that are currently online.
   */
  getOnlineMachines(): Machine[] {
    const online: Machine[] = [];
    for (let i: number = 0; i < this.machines.length; i++) {
      if (this.machines[i].isOnline) {
        online.push(this.machines[i]);
      }
    }
    return online;
  }

  /**
   * Process a machine: decrypt DEK and metadata.
   */
  private async processMachine(machine: Machine): Promise<void> {
    if (machine.dataEncryptionKey.length > 0) {
      this.dataKeyManager.decryptDataKey(machine.dataEncryptionKey, machine.id);
    }
    await this.decryptMachineMetadata(machine);
  }

  /**
   * Decrypt machine metadata JSON to extract the name.
   * Machine metadata is encrypted with AES-GCM using the machine's DEK.
   * Uses MachineEncryption.decryptRpcResult which handles the same format.
   */
  private async decryptMachineMetadata(machine: Machine): Promise<void> {
    if (machine.metadata.length === 0) {
      return;
    }

    const decrypted: string | null = await this.machineEncryption.decryptRpcResult(
      machine.id, machine.metadata
    );
    if (decrypted === null) {
      Logger.warn(TAG, `Failed to decrypt metadata for machine ${machine.id}`);
      return;
    }

    const meta: DecryptedMachineMeta = this.parseMachineMetadata(decrypted);
    machine.decryptedName = meta.name;
  }

  /**
   * Parse decrypted machine metadata JSON string.
   * Expected format: { "name": "..." }
   */
  private parseMachineMetadata(jsonString: string): DecryptedMachineMeta {
    try {
      const parsed: DecryptedMachineMeta = JSON.parse(jsonString) as DecryptedMachineMeta;
      return parsed;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to parse machine metadata: ${errMsg}`);
      return new DecryptedMachineMeta();
    }
  }

  /**
   * Find a machine by ID.
   */
  private findMachine(id: string): Machine | null {
    for (let i: number = 0; i < this.machines.length; i++) {
      if (this.machines[i].id === id) {
        return this.machines[i];
      }
    }
    return null;
  }

  /**
   * Remove a machine by ID.
   */
  private removeMachineById(id: string): void {
    const index: number = this.findMachineIndex(id);
    if (index >= 0) {
      this.machines.splice(index, 1);
    }
  }

  /**
   * Find the index of a machine by ID.
   */
  private findMachineIndex(id: string): number {
    for (let i: number = 0; i < this.machines.length; i++) {
      if (this.machines[i].id === id) {
        return i;
      }
    }
    return -1;
  }
}

export { MachineSync };
